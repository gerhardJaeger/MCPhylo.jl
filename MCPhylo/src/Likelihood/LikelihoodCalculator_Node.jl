# TODO: Look into Parallelizing it
"""
    FelsensteinFunction(tree_postorder::Vector{Node}, pi::Float64, rates::Vector{Float64})

This function calculates the log-likelihood of an evolutiuonary model using the
Felsensteins pruning algorithm.
"""
function FelsensteinFunction(tree_postorder::Vector{Node}, pi_::Number, rates::Vector{Float64}, n_c::Int64)::Float64

    for node in tree_postorder
        if node.nchild !== 0
            CondLikeInternal(node, pi_, rates, n_c)
        end # if
    end # for

    # sum the two rows
    rdata::Array{Float64,2}=last(tree_postorder).data
    res::Float64 = 0.0
    _pi_::Float64 = log(1.0-pi_)
    _lpi_::Float64 = log(pi_)
    @inbounds for ind in 1:n_c
        res +=(log(rdata[1,ind])+ _lpi_) + (log(rdata[2,ind])+ _pi_)

        #rdata[1, ind] *pi_
        #rdata[2, ind] *=_pi_
    end

    return res#sum(log.(rdata.*[pi_, 1.0-pi_]))
end # function


function CondLikeInternal(node::Node, pi_::Number, rates::Vector{Float64}, n_c::Int64)::Nothing
    @assert size(node.child)[1] == 2
    @assert size(rates)[1] == n_c
    left_daughter::Node = node.child[1]
    right_daughter::Node = node.child[2]
    linc::Float64 = left_daughter.inc_length
    rinc::Float64 = right_daughter.inc_length
    left_daughter_data::Array{Float64,2} = left_daughter.data
    right_daughter_data::Array{Float64,2} = right_daughter.data

    # use the inbounds decorator to enable SIMD
    # SIMD greatly improves speed!!!
    @simd for ind=eachindex(rates)
        @inbounds r::Float64 = rates[ind]

        @fastmath ext::Float64 = exp(-linc*r)
        ext_::Float64 = 1.0-ext
        p_::Float64 = 1.0-pi_
        v_::Float64 = ext_*pi_
        w_::Float64 = ext_*p_
        v1::Float64 = ext+v_
        v2::Float64 = ext+w_

        @inbounds a::Float64 = data[1,ind, left_daughter]*v1 + data[2,ind, left_daughter]*v_
        @inbounds b::Float64 = data[1,ind, left_daughter]*w_ + data[2,ind, left_daughter]*v2

        @fastmath ext = exp(-rinc*r)
        ext_ = 1.0-ext
        v_ = ext_*pi_
        w_ = ext_*p_
        v1 = ext+v_
        v2 = ext+w_

        @inbounds c::Float64 = data[1,ind, right_daughter]*v1 + data[2,ind, right_daughter]*v_
        @inbounds d::Float64 = data[1,ind, right_daughter]*w_ + data[2,ind, right_daughter]*v2

        @inbounds data[1,ind, node] = a*c
        @inbounds data[2,ind, node] = b*d
    end # for
end # function

function GradiantLog(tree_preorder::Vector{Node}, pi_::Number)
    root::Node = tree_preorder[1]
    n_c::Int64 = size(root.data)[2]
    Up::Array{Float64,3} = ones(length(tree_preorder)+1, size(root.data)[1], n_c)
    Grad_ll::Array{Float64} = zeros(length(tree_preorder))
    for node in tree_preorder
        if node.binary == "1"
            # this is the root
            @inbounds for i in 1:n_c
                Up[node.num,1,i] = pi_
                Up[node.num,2,i] = 1.0-pi_
            end # for
        else
            sister::Node = get_sister(root, node)
            mother::Node = get_mother(root, node)
            node_ind::Int64 = node.num

            Up[node_ind,:,:] = pointwise_mat(Up[node_ind,:,:], sister.data, n_c)
            Up[node_ind,:,:] = pointwise_mat(Up[node_ind,:,:], Up[mother.num,:,:], n_c)
            #Up[node_ind,:,:].*=sister.data
            #Up[node_ind,:,:].*=Up[parse(Int, mother.binary, base=2),:,:]

            my_mat::Array{Float64,2} = exponentiate_binary(pi_, node.inc_length, 1.0)

            #a::Array{Float64,1} = node.data[1,:].*my_mat[1,1] .+ node.data[2,:].*my_mat[2,1]
            #b::Array{Float64,1} = node.data[1,:].*my_mat[1,2] .+ node.data[2,:].*my_mat[2,2]
            a::Array{Float64,1} = my_dot(node.data, my_mat[:,1], n_c)
            b::Array{Float64,1} = my_dot(node.data, my_mat[:,2], n_c)

            #gradient::Array{Float64,1} = Up[node_ind,1,:].*a .+ Up[node_ind,2,:].*b
            gradient::Array{Float64,1} = pointwise_vec(Up[node_ind,1,:],a, n_c) .+ pointwise_vec(Up[node_ind,2,:],b,n_c)

            #Up[node_ind,1,:] = Up[node_ind,1,:].*my_mat[1,2] + Up[node_ind,2,:].*my_mat[2,2]
            #Up[node_ind,2,:] = Up[node_ind,1,:].*my_mat[1,1] + Up[node_ind,2,:].*my_mat[2,1]
            Up[node_ind,1,:] = my_dot(Up[node_ind,:,:], my_mat[:,2], n_c)
            Up[node_ind,2,:] = my_dot(Up[node_ind,:,:], my_mat[:,1], n_c)

            #d = sum(Up[node_ind,:,:].*node.data, dims=1)
            d = sum(pointwise_mat(Up[node_ind,:,:],node.data, n_c), dims=1)
            gradient ./= d[1,:]
            Grad_ll[node_ind] = sum(gradient)

            if node.nchild == 0
                scaler = sum(Up[node_ind,:,:], dims=1)
                Up[node_ind,:,:] ./= scaler
            end # if
        end # if
    end # for
    return Grad_ll

end # function
