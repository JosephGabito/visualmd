import '../../application/ports/workspace_ids.dart';
import '../../domain/workspace/workspace_id.dart';
import '../opaque_ids.dart';

/// Locally generated opaque ids; persistence, not their spelling, is identity.
final class RandomWorkspaceIds implements WorkspaceIds {
  @override
  WorkspaceId workspaceId() => WorkspaceId(OpaqueIds.next('workspace'));

  @override
  WorkspaceSourceId sourceId() => WorkspaceSourceId(OpaqueIds.next('source'));
}
