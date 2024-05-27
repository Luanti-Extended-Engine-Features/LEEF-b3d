# MTUL-b3d
a b3d library that use's [Appgurue's work](https://github.com/appgurueu/modlib), a b3d reader, and expands it's usefulness into node reading, global transformation solving,
and more- mostly in one package. Online documentation can be found [here](https://minetest-unification-library.github.io/MTUL-b3d/).

dependencies
* MTUL-core: provides binary reading (potential rename)
* MTUL-cpml: OPTIONAL allows use of b3d_nodes library (for node solving)

features:
* read a b3d file
* ignore specified chunks while reading a b3d file
* find a node by it's name
* solve the global position of a node
* solve the global rotation of a node
* solve the global transformation of a node (mat4)

todo:
* allow use of `get_node_by_name()` without CPML. (move to b3d_reader or set alias?)
* document b3d table contents (I already wrote most of the documentation in modlib's wiki...)
* finish b3d writer (NOTE: must offset "frame" by +1 as the reader is modified to match irrlicht)

Without Appgurue's Modlib this would not be possible, and while I personally have my issues with it, it still provides useful tools, and it's worth looking into for libraries.
