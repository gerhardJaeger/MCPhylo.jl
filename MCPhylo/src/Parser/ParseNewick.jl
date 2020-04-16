
# that's very far from ideal, but atom and I don't understand each other otherwise
include("../MCPhylo.jl")
#include("../Tree/Node_Type.jl")
#include("../Tree/Tree_Basics.jl")
include("../Tree/Tree_Traversal.jl")



"""
    ParseNewick(filename::String)

This function parses a Newick file
"""
function ParseNewick(filename::String)
    content = load_newick(filename)
    if !is_valid_newick_string(content)
        throw("$filename is not a Newick file!")
    end # if
    content = strip(content)

    #the parse thing
    # TODO: actually useful part of the code goes here


end


"""
    load_newick(filename::String)

This function loads a newick from file
"""
# TODO: rn it assumed that there are no extra line breaks (\n\n) and there is only one tree pro file. That should be fixed.

function load_newick(filename::String)
    open(filename, "r") do file
        global content = readlines(file)
    end
    content[1]
end

"""
    is_valid_newick_string(newick::String)

This function checks if the given string is valid: is the brackets number matches and if the string ends with ";"
"""

function is_valid_newick_string(newick::String)
    # Step one: does the stripped string ends with ';'
    if endswith(strip(newick),";")
        # Step two: check for the equal amount of brackets
        bracket_level = 0
        for char in newick
            if char == '('
                bracket_level += 1
            elseif char == ')'
                    bracket_level -= 1
            end # elseif
        end # for
        if bracket_level != 0
            return false
        end # if
    else # same level as the endswith statement
        return false
    end # else
    return true
end

# the grand line between functions which are we more certain in and experimental functions on which we are still working on

###########

#DISCLAIMER: this function is heavily inspired by the pseudocode provided by https://eddiema.ca/2010/06/25/parsing-a-newick-tree-with-recursive-descent/

#currently we shrink the string instead of following it with the cursor. Cursor should be less time complex, but string is more visual
# TODO: rewrite to the cursor version, remove all exessive println'es, etc

#the possible alternative parsing method, who knows
function testing_new_strat(newick::String, current_node::Any, count::Integer)
    if current_node == nothing
        count = 0
        current_node = Node()
    end #if
    println("it begins")
    println("current newick: ",newick)

    while true
         # if newick[1] == '('
         #     #this deals with the open parenthesis
         #     newick = SubString(newick,2)

            if newick[1] == '(' #TODO
                #this is recursion; if we're looking at an internal node this should happen
                println("ALERT: recursion needed")
                childs_section = match(r"\(([^()]|(?R))*\)",newick) #should return only the descendants of the current child node, check https://regex101.com/r/lF0fI1/1 for proof of this regex working the way it should
                childs_section = childs_section.match
                index=findlast(")",childs_section)[1]+1
                the_rest = SubString(childs_section,index)
                newick = the_rest
                childs_section = SubString(childs_section,2,findlast(')',childs_section)-1)
                cur_child = Node()
                add_child!(current_node,testing_new_strat(string(childs_section),cur_child,count)) #where the magic happens
                if newick[1] == ':'
                    node_boarder = match(r"[();,]",newick).offset
                    name,length = parse_name_length(string(SubString(newick,1,node_boarder-1)))
                    current_node.inc_length = length
                    current_node.num = count
                    newick = SubString(newick,node_boarder)
                end #if
            end #if

            if occursin(r"^[0-9A-Za-z_|]+",string(newick[1])) || newick[1] == ':'
                #this should happen if the current node's a leaf node
                node_boarder = match(r"[();,]",newick).offset
                name,length = parse_name_length(string(SubString(newick,1,node_boarder-1)))
                cur_child = Node()
                cur_child.name = name
                cur_child.inc_length = length
                cur_child.num = count
                add_child!(current_node,cur_child)
                newick = SubString(newick,node_boarder)
            end #if
            if newick[1] == ',' #we don't need these i don't think, just gotta look at the next thing
                newick = SubString(newick,2)
            end #if
            if newick[1] == ""
                #the third possibility; should just return the current node, move out of recursion, etc
                return current_node
            end #if
        end #while
    end #function
function parsing_the_newick(newick::String,current_node::Any,count::Integer)

    if current_node == nothing
        count = 0
        current_node = Node()
        println("Starting up!")
        println("The string is looking like that ", newick)
    end # setting things up

while true

    if newick[1] == '('

        newick = SubString(newick,2)
        println("Parsing... ",newick)

        if newick[1] == '('
            # YOUR RECURSION IS HERE
            println("Left bracket is detected!")
            left_child = parsing_the_newick(string(newick),current_node,count)
            newick = SubString(newick,2)
            println("Plus one happy kid gets a mom!")
            left_child.mother = current_node
            push!(current_node.children,left_child)
            println("Parsing... ",newick)
        end # if (the recursive call one)

        node_boarder = match(r"[();,]",newick).offset
        println("Trying to detect the name and length from the ", string(SubString(newick,1,node_boarder-1)))
        name,length = parse_name_length(string(SubString(newick,1,node_boarder-1)))

        left_child = Node()
        left_child.name = name
        left_child.inc_length = length
        left_child.num = count
        count+=1
        add_child!(current_node,left_child)
        newick = SubString(newick,node_boarder)
        println("The left child was succesfully attached. Continiue to parse ",newick)
    end # if "("
if newick[1] == ','

    sibling_parsing = true
    while sibling_parsing

    if newick[1] == ','

        newick = SubString(newick,2)
        println("Parsing... ",newick)

        if newick[1] == '('
            println("Welcome to the internal node. Here starts the recursion.")
            right_child = parsing_the_newick(string(newick),current_node,count)
            println("Moving on! The current string is ", newick)
            newick = SubString(newick,2)
            println("Plus one happy kid gets a mom!")
            right_child.mother = current_node
            push!(current_node.children,right_child)


        end # if (the recursive call one)

        node_boarder = match(r"[();,]",newick).offset
        println("Trying to detect the name and length from the ", string(SubString(newick,1,node_boarder-1)))
        name,length = parse_name_length(string(SubString(newick,1,node_boarder-1)))

        right_child = Node()
        right_child.name = name
        right_child.inc_length = length
        right_child.num = count
        count+=1
        add_child!(current_node,right_child)
        newick = string(SubString(newick,node_boarder))
        println("The right child was succesfully attached. Continiue to parse ", newick)
else
    sibling_parsing=false
    end # if ","

end # while
end # if ','

    if newick[1] == ')'
        println("Some right brakcet was detected!")
        newick = string(SubString(newick,2))
        println("Continiue to parse... ", newick)
end # if with the ")" bracket

if occursin(r"^[0-9A-Za-z_|]+",string(newick[1])) || newick[1] == ':'
        println("We're getting the information of the current node")
        node_boarder = match(r"[();,]",newick).offset
        println("Trying to detect the name and length from the ", string(SubString(newick,1,node_boarder-1)))
        name,length = parse_name_length(string(SubString(newick,1,node_boarder-1)))
        current_node.name = name
        current_node.inc_length = length
        current_node.num = count
        count+=1
        newick = SubString(newick,node_boarder)
        println("Information about the current node was written down. Continue to parse... ",newick)
    end # if length one
    if newick[1] == ';'
        println("We have reached the end!")
        return current_node
    end # the last one
end #while
    return current_node
end # the function


"""
    parse_name_length(newick::String)

This function parses two optional elements of the tree, name and length. In case, when neither of this is provided, empty string and nothing are return
"""

function parse_name_length(newick::String)
    newick = strip(newick)
    if length(newick) < 1
        return "no_name", 0.0
    end # if length
    if occursin(':',newick)
        name, len = split(newick,':')
        return string(name), parse(Float64, len)
    end # if occusrsin
    return newick, 0.0
end # function

print(testing_new_strat("(Swedish_0:0.1034804,(Welsh_N_0:0.1422432,(Sardinian_N_0:0.02234697,(Italian_0:0.01580386,Rumanian_List_0:0.03388825):0.008238525):0.07314805):0.03669193,(((Marathi_0:0.04934081,Oriya_0:0.02689862):0.1193376,Pashto_0:0.1930713):0.05037896,Slovenian_0:0.0789572):0.03256979);",nothing,0))

# minimal setting up examples


# println("it begins")
# F = parsing_the_newick("(A,B,E)F;",nothing,0)
# println("it is finished")
# bla = F.children
# for x in bla
#     name = x.name
#     children = x.children
#     mother = x.mothe
#     println("HELLO I AM ",name, " MY CHILDREN ARE ", children, " MY MOTHER IS ", mother)
# end #for




# TODO: rewrite this one
#
function make_node(newick::String)
    parts = split(newick, ')')
    if length(parts) == 1
        label = newick
        children = Vector{Node}(undef, 0)
        name, inc_length = parse_name_length(label)
        return Node{Float64,Array{Float64,2},Array{Float64},Int64}(name,ones(3,3),missing,children,ones(3),3,false,inc_length,"0",1,0.5,nothing,nothing,true)
    else
        # TODO: why can't we use length? check
        len_minus_one = size(parts,1)-1
        children = list(parse_siblings(join(parts[len_minus_one],')')[2:size(parts,1)]))
        label = parts[len_minus_one]
    end #if
    name, inc_length = parse_name_length(label)
    parent = Node(name,ones(3,3),missing,children,length(children),false,inc_length,"0",1,0.5,nothing,nothing,true)
    for x in children
        x.mother=parent
    end #for
    return parent
end #function



function parse_siblings(newick::String)
    bracket_lvl = 0
    current = []
    for c in  (newick * ',')
        if c == ','
            if bracket_lvl == 0
                yield(make_node(join(current,"")))
                current = []
            else
                if c == '('
                    bracket_lvl += 1
                elseif c == ')'
                    bracket_lvl -= 1
                end #elseif
            end #if
            push!(current,c)
        end #if
    end #for
end #function
