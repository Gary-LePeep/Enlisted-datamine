module nphys_jumplink_climb_common shared


def should_climb(path_corridor__overJumpLink : bool;
                 path_corridor__jumpLinkStart, path_corridor__jumpLinkEnd : float3;
                 navmesh_phys__climbMinHeight : float)
  return (path_corridor__overJumpLink
          && path_corridor__jumpLinkEnd.y - path_corridor__jumpLinkStart.y >= navmesh_phys__climbMinHeight)

