"""
    parse_and_number(treestring::S)::GeneralNode where S<:AbstractString

--- INTERNAL ---
Parse a newick string and then call set_binary and number_nodes! on the
resulting tree
"""
function parse_and_number(treestring::S)::GeneralNode where S<:AbstractString
    p_tree2 = parsing_newick_string(string(treestring))
    set_binary!(p_tree2)
    MCPhyloTree.number_nodes!(p_tree2)
    p_tree2
end # parse_and_number


"""
    ASDSF(args::String...; freq::Int64=1, check_leaves::Bool=true,
          min_splits::Float64=0.1, show_progress::Bool=true)::Vector{Float64}

Calculate the average standard deviation of split frequencies for two or more
files containing newick representations of trees. Default frequency is 1 and
by default only trees with the same leafsets are supported. The default minimal
splits threshold is 0.1. The progress bar is activated by default.
"""
function ASDSF(args::String...; freq::Int64=1, check_leaves::Bool=true,
               min_splits::Float64=0.1, show_progress::Bool=true
               )::Vector{Float64}

    length(args) < 2 && throw(ArgumentError("At least two input files are needed."))
    splitsQueue = [Accumulator{Tuple{String, String}, Int64}()]
    splitsQueues = [Vector{Accumulator{Tuple{String, String}, Int64}}()]
    for arg in args
        push!(splitsQueues[1], Accumulator{Tuple{Set{String}, Set{String}}, Int64}())
    end # for
    iter = zip([eachline(arg) for arg in args]...)
    nsams = countlines(args[1]) / freq
    asdsf_size = ceil(Int,nsams)
    ASDSF_vals = [zeros(ceil(Int,asdsf_size))]

    # tree_dims is hardcoded to 1 because there are no multiple dims in files
    res = ASDSF_int(splitsQueue, splitsQueues, iter, 1, ASDSF_vals, freq, check_leaves,
              min_splits, show_progress, basic=true)[1][1]
    asdsf_size > nsams ? res[1:end-1] : res
end # ASDSF


"""
    ASDSF(args::Vector{String}...; freq::Int64=1, check_leaves::Bool=true,
          min_splits::Float64=0.1, show_progress::Bool=true)::Vector{Float64}

Calculate the average standard deviation of split frequencies for two or more
Vectors containing newick representations of trees. Default frequency is 1 and
by default only trees with the same leafsets are supported. The default minimal
splits threshold is 0.1. The progress bar is activated by default.
"""
function ASDSF(args::Vector{String}...; freq::Int64=1, check_leaves::Bool=true,
               min_splits::Float64=0.1, show_progress::Bool=true
               )::Vector{Float64}

    length(args) < 2 && throw(ArgumentError("At least two input arrays are needed."))
    splitsQueue = [Accumulator{Tuple{String, String}, Int64}()]
    splitsQueues = [Vector{Accumulator{Tuple{String, String}, Int64}}()]
    for arg in args
        push!(splitsQueues[1], Accumulator{Tuple{Set{String}, Set{String}}, Int64}())
    end # for
    iter = zip(args...)
    ASDSF_vals = [zeros(Int(length(iter) / freq))]
    # tree_dims is hardcoded to 1 because there are no multiple dims in Vectors
    ASDSF_int(splitsQueue, splitsQueues, iter, 1, ASDSF_vals, freq, check_leaves,
              min_splits, show_progress; basic=true)[1]
end # ASDSF


"""
    ASDSF(model::ModelChains; freq::Int64=1, check_leaves::Bool=true,
          min_splits::Float64=0.1, show_progress::Bool=true
          )::Vector{Vector{Float64}}

Calculate the average standard deviation of split frequencies for the trees in
different chains in a ModelChains object. Default frequency is 1 and by default
only trees with the same leafsets are supported. The default minimal splits
threshold is 0.1. The progress bar is activated by default.
"""
function ASDSF(model::ModelChains; freq::Int64=1, check_leaves::Bool=true,
               min_splits::Float64=0.1, show_progress::Bool=true
               )::Vector{Vector{Float64}}
               
    tree_dims::UnitRange{Int64} = 1:size(model.trees, 2)
    splitsQueue = [Accumulator{Tuple{String, String}, Int64}() for x in tree_dims]
    splitsQueues = [Vector{Accumulator{Tuple{String, String}, Int64}}() for x in tree_dims]
    nchains = size(model.trees, 3)
    for i in 1:nchains
        for j in tree_dims
            push!(splitsQueues[j], Accumulator{Tuple{Set{String}, Set{String}}, Int64}())
        end # for
    end # for
    trees = Array{Vector{AbstractString}, 2}(undef, size(model.trees, 1), nchains)
    if length(tree_dims) > 1
        trees = Array{Vector{AbstractString}, 2}(undef, size(model.trees, 1), nchains)
        for i in 1:size(model.trees, 1)
            for j in 1:nchains
                trees[i, j] = model.trees[i,:,j]
            end # for
        end # for
    end # if
    iter = zip([trees[:,c] for c in 1:nchains]...)
    ASDSF_vals::Vector{Vector{Float64}} = [zeros(Int(floor(length(iter) / freq))) for x in tree_dims]
    ASDSF_int(splitsQueue, splitsQueues, iter, tree_dims, ASDSF_vals, freq,
              check_leaves, min_splits, show_progress)
end # ASDSF


"""
    ASDSF(r_channels::Vector{RemoteChannel}, n_trees::Int64,
          tree_dims::UnitRange{Int64}, min_splits::Float64
          )::Tuple{Vector{Vector{Float64}}, ConvergenceStorage}

--- INTERNAL ---
Calculates - on-the-fly - the average standard deviation of split frequencies
for the trees generated by MCMC draws from a model. Takes a vector of remote
channels (where the generated trees are stored during the mcmc simulation) and
the total number of trees in each chain as arguments. The default minimal splits
threshold is 0.1.
"""
function ASDSF(r_channels::Vector{RemoteChannel{Channel{Array{AbstractString,1}}}},
               n_trees::Int64, tree_dims::UnitRange{Int64}, min_splits::Float64;
               cs::Union{Nothing, ConvergenceStorage}=nothing
               )::Tuple{Vector{Vector{Float64}}, ConvergenceStorage}

    iter = 1:n_trees
    ASDSF_vals::Vector{Vector{Float64}} = [zeros(Int(n_trees)) for x in tree_dims]
    nchains = length(r_channels)
    if isnothing(cs)
        splitsQueue = [Accumulator{Tuple{String, String}, Int64}() for x in tree_dims]
        splitsQueues = [Vector{Accumulator{Tuple{String, String}, Int64}}() for x in tree_dims]
        for i in 1:nchains
            for j in tree_dims
                push!(splitsQueues[j], Accumulator{Tuple{Set{String}, Set{String}}, Int64}())
            end # for
        end # for
        ASDSF_int(splitsQueue, splitsQueues, iter, tree_dims, ASDSF_vals, 1, false,
                  min_splits, false; r_channels=r_channels)
    else
        splitsQueue = cs.splitsQueue
        splitsQueues = cs.splitsQueues
        run = cs.run
        ASDSF_int(splitsQueue, splitsQueues, iter, tree_dims, ASDSF_vals, 1,
                  false, min_splits, false; r_channels=r_channels,
                  total_runs=run)
    end # if/else
end # ASDSF


"""
    ASDSF_int(splitsQueue, splitsQueues, iter, tree_dims, ASDSF_vals, freq,
              check_leaves, min_splits, show_progress; r_channels=nothing,
              run::Int64=1, basic=false
              )::Tuple{Vector{Vector{Float64}}, ConvergenceStorage}

--- INTERNAL ---
Handles the computation of the Average Standard Deviation of Split Frequencies.
"""
function ASDSF_int(splitsQueue, splitsQueues, iter, tree_dims, ASDSF_vals, freq,
                   check_leaves, min_splits, show_progress; r_channels=nothing,
                   total_runs::Int64=1, basic=false
                   )::Tuple{Vector{Vector{Float64}}, ConvergenceStorage}

    all_keys = [Set{Tuple{String,String}}() for x in tree_dims]
    
    if show_progress
        prog = ProgressMeter.Progress(length(ASDSF_vals[1]),"Computing ASDSF: ")
    end # if
    gen = 1
    
    for (i, line) in enumerate(iter)
        if mod(i, freq) == 0
            if !isnothing(r_channels)
                line = [take!(rc) for rc in r_channels]
            end
            for td in tree_dims
                trees = basic ? [parse_and_number(tree) for tree in line] :
                                [parse_and_number(tree[td]) for tree in line]
                check_leaves && check_leafsets(trees)

                # get all bipartitions
                cmds = Accumulator.(countmap.(get_bipartitions.(trees)))
                
                for (ind,acc) in enumerate(cmds)
                    merge!(splitsQueues[td][ind], acc)
                end
                new_splits = merge(cmds...)
                
                all_keys[td] = union(all_keys[td], keys(new_splits))
                merge!(splitsQueue[td], new_splits)
                
                tmp = 0.0
                M = 0.0
                for split in all_keys[td]
                    tmp_i = 0.0
                    keep = false
                    ova = splitsQueue[td][split]/(length(trees)*total_runs)
                    for r in 1:length(trees)
                        if splitsQueues[td][r][split]/total_runs > min_splits
                            keep = true
                        end
                        tmp_i += (splitsQueues[td][r][split]/total_runs - ova)^2
                        
                    end
                    tmp_i /= (length(trees)-1)
                    tmp += keep ? sqrt(tmp_i) : 0.0
                    M += keep ? 1 : 0    
                end
                ASDSF_vals[td][gen] = tmp / M

            end # for
            gen += 1
            total_runs += 1
            show_progress && ProgressMeter.next!(prog)
        end # if
    end # for
    show_progress && ProgressMeter.finish!(prog)
    conv_storage = ConvergenceStorage(splitsQueue, splitsQueues, total_runs)
    ASDSF_vals, conv_storage
end # ASDSF_int