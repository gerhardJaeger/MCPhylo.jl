module Tree_moves

include("./Tree_Basics.jl")
using Markdown
using Random
using Distributions

using ..Tree_Basics: Node, post_order, set_binary!, add_child!, remove_child!, random_node

export NNI!

"""
    NNI!(root::Node)

This function performs an inplace nearest neighbour interchange operation on the
tree which is supplied.
"""
function NNI!(root::Node)

    target::Node = Node(1.0, [0.0], Node[], 0, true, 0.0, "0")
    while true
        target = random_node(root)
        # check if target is not a leave and that its grand daughters are also
        # no leaves
        if target.nchild != 0
            if target.child[1].nchild !=0
                if target.child[2].nchild !=0
                    break
                end
            end # if
        end # if
    end # end while

    if rand([1,2]) == 1
        child1 = remove_child!(target, 1)
        child2 = remove_child!(target, 2)

        gchild1 = remove_child!(child1, 1)
        gchild2 = remove_child!(child1, 1)
    else
        child1 = remove_child!(target, 2)
        child2 = remove_child!(target, 1)
        gchild1 = remove_child!(child1, 1)
        gchild2 = remove_child!(child1, 1)
    end # if

    add_child!(target, child1)
    add_child!(target, gchild1)
    add_child!(child1, child2)
    add_child!(child1, gchild2)

    set_binary!(root)

end # function NNI!

"""
    slide!(root::Node)

This functin performs a slide move on an intermediate node. The node is moved
upwards or downwards on the path specified by its mother and one of its
daughters.
"""
function slide!(root::Node)
    target::Node = Node(1.0, [0.0], Node[], 0, true, 0.0, "0")
    while true
        target = random_node(root)
        # check if target is not a leave and that its grand daughters are also
        # no leaves
        if target.nchild != 0
            if target.child[1].nchild !=0
                if target.child[2].nchild !=0
                    break
                end
            end # if
        end # if
    end # end while

    # proportion of slide move is randomly selected
    proportion::Float64 = randn(Uniform(0,1))

    # pick a random child
    child::Node = target.child[rand([1,2])]

    # calculate and set new values
    total::Float64 = target.inc_length + child.inc_length
    fp::Float64 = total*proportion
    sp::Float64 = total-fp

    target.inc_length = fp
    child.inc_length = sp

end # function slide!


end # module Tree_moves
