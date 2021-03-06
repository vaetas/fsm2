import 'fork_definition.dart';
import 'graph_builder.dart';

import 'types.dart';

/// State builder.
///
/// Instance of this class is passed to [GraphBuilder.state] method.
class ForkBuilder<E extends Event> {
  final ForkDefinition<E> _forkDefinition;

  ForkBuilder() : _forkDefinition = ForkDefinition<E>();

  ForkDefinition build() => _forkDefinition;

  void target<S extends State>() {
    _forkDefinition.addTarget(S);
  }
}
