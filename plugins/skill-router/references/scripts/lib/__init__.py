"""skill-router internal library package.

This package contains the routing pipeline implementation.  Modules
are kept import-compatible with direct execution (`python build_index.py`)
because the hook entry-points run them as scripts; the ``__init__.py``
exists only to mark this directory as a package so that future callers
can ``import skill_router_lib.embedding_client`` after path injection.
"""
