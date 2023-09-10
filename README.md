# MTUL-b3d-standalone
a b3d library that use's [Appgurue's work](https://github.com/appgurueu/modlib), a b3d reader, and expands it's usefulness into node reading, global transformation solving, 
and more- mostly in one package. Online documentation can be found [here](https://minetest-unification-library.github.io/MTUL-b3d-standalone/). 

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

Without Appgurue's Modlib this would not be possible, and while I personally have my issues with it, it still provides useful tools, and it's worth looking into for libraries.
