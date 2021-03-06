import 'package:fsm2/src/exceptions.dart';
import 'package:fsm2/src/state_builder.dart';

import 'transitions/noop_transition.dart';
import 'transitions/transition_definition.dart';
import 'types.dart';

enum _ChildrenType { nested, concurrent }

class StateDefinition<S extends State> {
  StateDefinition(this.stateType);

  /// If this is a nested state the [parent]
  /// is a link to the parent of this state.
  /// If this is not a nested state then parent will be null.
  StateDefinition _parent;

  void setParent<P extends State>(StateDefinition<P> parent) {
    // log('set parent = ${parent.stateType} on ${stateType} ${hashCode}');
    _parent = parent;
  }

  StateDefinition get parent => _parent;

  /// The Type of the [State] that this [StateDefinition] is for.
  final Type stateType;

  /// The maps the set of [TransitionDefinition]s for a given [Event]
  /// for this [State].
  /// [TransitionDefinition] are defined via calls to [on], [onFork] or [onJoin]
  /// methods. There can be multiple transitions for each
  /// event due to the [condition] argument (which is a guard condition).
  ///
  /// There can also be multiple events that need to be mapped to a single
  /// [TransitionDefinition] in which case the [TransitionDefinition] will
  /// be in this map twice.
  final Map<Type, List<TransitionDefinition>> _eventTranstionsMap = {};

  // ignore: unused_field
  _ChildrenType _childrenType;

  /// State definitions for the set of immediate children of this state.
  final Map<Type, StateDefinition> childStateDefinitions = {};

  /// callback used when we enter this [State].
  /// Provide provide a default no-op implementation.
  OnEnter onEnter = (Type toState, Event event) {
    return null;
  };

  /// callback used when we exiting this [State].
  /// Provide provide a default no-op implementation.
  OnExit onExit = (Type fromState, Event event) {
    return null;
  };

  /// Returns the first transition that can be triggered for the given [event] from the
  /// given [fromState].
  ///
  /// When considering each event we must evaulate the guard condition to determine if the
  /// transition is valid.
  ///
  /// If no triggerable [event] can be found for the [fromState] then a [NoOpTranstionDefinition] is returned
  /// indicating that no transition will occur under the current conditions.
  ///
  /// If no matching [event] can be found for the [fromState] then an [InvalidTransitionException] is thrown.
  ///
  /// When searching for an event we have to do a recursive search (starting at the [fromState])
  /// up the tree of nested states as any events on an ancestor [State] also apply to the child [fromState].
  ///
  Future<TransitionDefinition> findTriggerableTransition<E extends Event>(Type fromState, E event) async {
    TransitionDefinition transitionDefinition;

    if (!hasTransition(fromState, event)) {
      throw InvalidTransitionException(fromState, event);
    }

    /// does the current state definition have a transition for the give event.
    transitionDefinition = await _evaluateTransitions(event);

    // If [fromState] doesn't have a transitionDefintion that can be triggered
    // then we search the parents.
    var parent = this.parent;
    while (transitionDefinition is NoOpTransitionDefinition && parent != VirtualRoot().definition) {
      transitionDefinition = await parent._evaluateTransitions(event);
      parent = parent.parent;
    }

    return transitionDefinition;
  }

  /// returns a [NoOpTransitionDefinition] if none of the transitions would be triggered
  /// or if there where no transitions for [event].
  Future<TransitionDefinition> _evaluateTransitions<E extends Event>(E event) async {
    var transitionChoices = _eventTranstionsMap[event.runtimeType] as List<TransitionDefinition<S, E>>;

    if (transitionChoices == null) {
      return NoOpTransitionDefinition<S, E>(this, E);
    }

    return await evaluateConditions(transitionChoices, event);
  }

  /// Evaluates each guard condition for the given [event]  from [fromState]
  ///
  /// Conditions are applied to determine which transition occurs.
  ///
  /// If no condition allows the transition to fire then we return
  /// a [NoOpTransitionDefinition] which result in no state transition occuring.
  ///
  Future<TransitionDefinition<S, E>> evaluateConditions<E extends Event>(
      List<TransitionDefinition<S, E>> transitionChoices, E event) async {
    assert(transitionChoices.isNotEmpty);
    for (var transitionDefinition in transitionChoices) {
      /// hack to get around typedef inheritance issues.
      dynamic a = transitionDefinition;
      if ((a.condition as dynamic) == null || (a.condition(event) as bool)) {
        /// static transition
        return transitionDefinition;
      }
    }
    return NoOpTransitionDefinition<S, E>(this, E);
  }

  /// A state is a terminal state if it has no transitions and
  /// therefore we can never leave this state.
  /// We need to check any parent states as we inherit
  /// transitions from all our ancestors.
  bool get isTerminal {
    return getTransitions(includeInherited: true).isEmpty;
    // return _eventTranstionsMap.isNotEmpty && (parent == null || parent.isTerminal);
  }

  /// A state is a leaf state if it has no child states.
  bool get isLeaf => childStateDefinitions.isEmpty;

  /// A state is an abstract state if it has any child states
  /// You cannot use an abstract state as an transition target.
  bool get isAbstract => childStateDefinitions.isNotEmpty || this == VirtualRoot().definition;

  /// Returns the set of transitions 'from' this state.
  /// As a state inherits any transitions defined by
  /// an ancestor this method also returns the transistions
  /// for all ancestors by default.
  ///
  /// The transitions are ordered from leaf to root.
  ///
  /// Set [includeInherited] to false to exclude inherited transitions.
  ///
  List<TransitionDefinition> getTransitions({bool includeInherited = true}) {
    var transitionDefinitions = <TransitionDefinition>[];

    for (var transitions in _eventTranstionsMap.values) {
      transitionDefinitions.addAll(transitions);
    }

    /// add inherited transitions.
    if (includeInherited) {
      var parent = this.parent;
      while (parent != VirtualRoot().definition) {
        transitionDefinitions.addAll(parent.getTransitions());

        parent = parent.parent;
      }
    }
    return transitionDefinitions;
  }

  // Future<List<TransitionDefinition>> getStaticTransitionsForEvent(Type fromState, Event event) async {
  //   TransitionDefinition transitionDefinition;
  //   for (var stateDefinition in childStateDefinitions.values) {
  //     transitionDefinition = await stateDefinition.findTriggerableTransition(fromState, event);

  //     if (transitionDefinition != null) break;
  //   }

  //   for (var transitions in _eventTranstionsMap.values) {
  //     for (var transition in transitions) {
  //       // TODO what is meant to happen here?
  //       if (transition.targetStates != null) {}
  //     }
  //   }

  //   transitionDefinition ??= await _evaluateTransitions(event);

  //   return [transitionDefinition];
  // }

  void addTransition<E extends Event>(TransitionDefinition<S, E> transitionDefinition) {
    var transitionDefinitions = _eventTranstionsMap[E];
    transitionDefinitions ??= <TransitionDefinition<S, E>>[];

    if (transitionDefinition.condition == null) {
      checkHasNoNullChoices(E);
    }

    transitionDefinitions.add(transitionDefinition);
    _eventTranstionsMap[E] = transitionDefinitions;
  }

  /// Adds a child state to this state definition.
  void addNestedState<C extends State>(BuildState<C> buildState) {
    final builder = StateBuilder<C>(C);
    buildState(builder);
    final definition = builder.build();
    definition.setParent(this);
    definition._childrenType = _ChildrenType.nested;
    childStateDefinitions[C] = definition;
  }

  /// Adds a child co-state to this state defintion.
  /// A state may have any number of costates.
  /// All co-states simultaneously have a state
  /// This allows
  void addCoState<CO extends State>(BuildCoState<CO> buildState) {
    final builder = CoStateBuilder<CO>(CO);
    buildState(builder);
    final definition = builder.build();
    definition.setParent(this);
    definition._childrenType = _ChildrenType.concurrent;
    childStateDefinitions[CO] = definition;
  }

  /// recursively searches through the list of nested [StateDefinitions]
  /// for a [StateDefinition] of type [stateDefinitionType];
  StateDefinition<State> findStateDefintion(Type stateDefinitionType) {
    StateDefinition found;
    for (var stateDefinition in childStateDefinitions.values) {
      if (stateDefinition.stateType == stateDefinitionType) {
        found = stateDefinition;
        break;
      } else {
        found = stateDefinition.findStateDefintion(stateDefinitionType);
        if (found != null) break;
      }
    }
    return found;
  }

  /// Returns a list of immediately nested [StateDefinition]s.
  /// i.e. we don't search child [StateDefinition]s for further
  /// nested [StateDefinition]s.
  List<StateDefinition> get nestedStateDefinitions {
    var definitions = <StateDefinition>[];

    if (childStateDefinitions.isEmpty) return definitions;

    for (var stateDefinition in childStateDefinitions.values) {
      definitions.add(stateDefinition);

      var nested = stateDefinition.nestedStateDefinitions;
      definitions.addAll(nested);
    }
    return definitions;
  }

  /// Checks that the [fromState] has a transition for [event].
  ///
  /// We search up the tree of nested states starting at [fromState]
  /// as any transitions on parent states can also be applied
  ///
  bool hasTransition<E extends Event>(Type fromState, E event) {
    var transitions = getTransitions();
    // var transitions = _eventTranstionsMap[event.runtimeType];

    if (transitions == null || transitions.isEmpty) return false;

    /// Do we have a transtion for [event]
    return transitions.fold<bool>(
        false, (found, transition) => found || transition.triggerEvents.contains(event.runtimeType));
  }

  void checkHasNoNullChoices(Type eventType) {
    if (_eventTranstionsMap[eventType] == null) return;
    for (var transitionDefinition in _eventTranstionsMap[eventType]) {
      // darts generic typedefs are broken for inheritence
      dynamic a = transitionDefinition;
      if ((a.condition as dynamic) == null) {
        throw NullChoiceMustBeLastException(eventType);
      }
    }
  }
}

class VirtualRoot implements State {
  static final _self = VirtualRoot._internal();
  var definition = StateDefinition<VirtualRoot>(VirtualRoot);

  factory VirtualRoot() => _self;

  /// make the ctor private.
  VirtualRoot._internal() {
    definition.setParent(definition);
  }
}
