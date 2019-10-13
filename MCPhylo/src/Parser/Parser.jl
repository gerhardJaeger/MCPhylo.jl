
"""
    make_tree_with_data(filename::String)::Node

This function creates a tree where the terminal nodes get the data specified in
the input file.
"""
function make_tree_with_data(filename::String, dialect::AbstractString="nexus"
                             gap::Union{Missing, AbstractString}=missing,
                             miss::Union{Missing,Abstract}=missing
                             header::Boolean=false)
    # get all the information from the input file
    if lowercase(dialect) == "nexus"
        n_tax, nc, gap, miss, df = ParseNexus(filename)
    elseif lowercase(dialect) == "csv"
        ismissing(gap) || throw("Please specify the gap symbol for a CSV file")
        ismissing(miss) || throw("Please specify the missing symbol for a CSV file")
        n_tax, nc, df = ParseCSV(filename, header)
    end
    # create random tree
    new_tree = create_tree_from_leaves(df[!,:Language], nc)

    n_nodes = length(post_order(new_tree))
    my_df = zeros(Float64, (n_nodes, 2, nc))
    # iterate through the data frame and get the node information
    for row in eachrow(df)
        #data_vec = zeros(Float64, (2, nc))
        mn = find_by_name(new_tree, row.Language)
        mind = mn.num
        for (ind, i) in enumerate(row.Data)
            if i == '0'
                my_df[mind, 1,ind] = 1.0
            elseif i == '1'
                my_df[mind,2,ind] = 1.0
            else
                my_df[mind,1, ind] = 1.0
                my_df[mind,2, ind] = 1.0
            end # if
        end # for
        #node = find_by_name(new_tree, row.Language)
        #node.data = log.(data_vec)
    end # for
    return new_tree, my_df
end # function make_tree_with_data