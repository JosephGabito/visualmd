import '../../domain/workspace/workspace.dart';

/// Port: the public workspace document format.
abstract interface class WorkspaceCodec {
  Workspace decode(String source);
  String encode(Workspace workspace);
}
