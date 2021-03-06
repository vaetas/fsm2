
FSM2 provides an implementation of the core design aspects of the UML state diagrams.

FMS2 is derived from the FSM library which in turn was inspired by [Tinder StateMachine library](https://github.com/Tinder/StateMachine).

State Machines transitions can be defined both declaratively and procedurally.

Guard Conditions from the UML 2 specification are also supported.


FSM2 uses a builder to delcare each state machine.

Your application may declare as many statemachines as necessary.

## Delcarative State Transitions


```dart
import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>())
 ));

```

The above examples creates a Finite State Machine (machine) which delcares its initial state as being `Solid` and then declares a single
transition which occurs when the event `OnMelted` event is triggered causing a transition to a new state `Liquid`.

To trigger an event:

```dart
machine.transition(OnMelted());
```
After the above call to transition `machine.currentState` will return `Liquid()`.



## Guard conditions
FSM2 supports guard conditions which only allow an event to cause a transition if the Event
or State meets some condition.

Guard conditions allow you to declare (via the `on` builder) the same Event multiple times from a single State.
When registring multiple events of the same type only a single event may have an empty guard condition and it MUST
be the last event added to the state.


If a State has the same event registered multiple times then the transitions will be evaluated in order.
The first transition whose guard condition returns true will be triggered.
No further guard conditions will be evaluated.
A transition without a Guard Condtions always evaluates to true.

```dart
import 'package:fsm2/fsm2.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnHeat, Liquid>(condition: s.temperature + e.deltaDegrees > 0)
       ..on<OnHeat, Boiling>(condition: s.temperature + e.deltaDegrees > 100)
      ..on<OnMelted, Liquid>())
 ));

```

You can see from the above example that the `OnHeat` contains a field `deltaDegrees`. It is often useful to pass
arguments to your events which can then be applied to the State. To pass a value into an event.

```dart
machine.transition(OnHeat(deltaDegrees: 25));
```


## Side Effects
FSM2 allows you to specify side effects for a transition. The side effect is a lambda which will be called when
the transition is triggered. A transition that fails to pass its guard condition will not be triggered and its side effect will not be called.

```dart
void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnHeat, Liquid>(sideEffect: () => print('I melted'), condition: s.temperature + e.deltaDegrees > 0)
 ));
 ```

## onEnter/onExit

The onEnter/onExit methods allow you to define actions that are peformed when we enter or leave a State.
It doesn't matter what event caused the new State.

An example might be calculating the State's pressure. It doesn't matter why we entered a State, the state must
always refect its current temperature so using an `onEnter` method makes this simple.


## Example
A simple example showing the life cycle of H2O.




```dart
import 'package:fsm/fsm.dart';

void main() {
  final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: () => print('Melted'),
          )))
    ..state<Liquid>((b) => b
      ..onEnter((s, e) => print('Entering ${s.runtimeType} State'))
      ..onExit((s, e) => print('Exiting ${s.runtimeType} State'))
      ..on<OnFroze, Solid>sideEffect: () => print('Frozen'),
          ))
      ..on<OnVaporized, Gas>(sideEffect: () => print('Vaporized'),
          )))
    ..state<Gas>((b) => b
      ..on<OnCondensed, Liquid>(sideEffect: () => print('Condensed'),
          )))
    ..onTransition((t) => print(
        'Recieved Event ${t.event.runtimeType} in State ${t.fromState.runtimeType} transitioning to State ${t.toState.runtimeType}')));

  print(machine.currentState is Solid); // TRUE

  machine.transition(OnMelted());
  print(machine.currentState is Liquid); // TRUE

  machine.transition(OnFroze());
  print(machine.currentState is Solid); // TRUE
}

```

# Analyze
FSM2 includes a method to check the integrity of your FSM machine.

The analyse method checks that there is a path from the initial state to every state in the tree.

The analyse method outputs a log noting any States that can't be reached.

To run an analysis:

```dart
final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: () => print('Melted'),
          )))
   ));
await machine.analyse();
```

# Visualise your FSM
It can be useful to visualise you FSM and with that in mind FSM2 is able to export your FSM to the dot format.

https://www.graphviz.org/doc/info/lang.html

There are a number of tools tha can display a dot file, the simplest is xdot which can be installed by:

```bash
apt install xdot
```

To generate a dot file run: 

```dart
final machine = StateMachine.create((g) => g
    ..initialState(Solid())
    ..state<Solid>((b) => b
      ..on<OnMelted, Liquid>(sideEffect: () => print('Melted'),
          )))
   ));
await machine.export('/path/to/dot/file');
```

You can then visualise the results via:

```bash
xdot /part/to/dot/file
```


## Example classes

The above examples use the following classes.

```dart
class Solid implements State {}

class Liquid implements State {}

class Gas implements State {}

class OnMelted implements Event {}

class OnFroze implements Event {}

class OnVaporized implements Event {}

class OnCondensed implements Event {}

class OnHeat implements Event {
  int deltaDegrees;
  OnHeat({this.deltaDegrees})
}
```



## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/bsutton/fsm2/issues
