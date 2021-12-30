## AbstractTrees interface

AbstractTrees.children(node::Node) = node.foldchildren ? typeof(node)[] : node.children

AbstractTrees.printnode(io::IO, node::Node) = print(io, node.foldchildren ? "+ " : "  ", node.data)
