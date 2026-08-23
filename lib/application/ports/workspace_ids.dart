import '../../domain/workspace/workspace_id.dart';

/// Port: creates opaque identities without coupling the domain to randomness.
abstract interface class WorkspaceIds {
  WorkspaceId workspaceId();
  WorkspaceSourceId sourceId();
}
