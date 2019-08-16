#=
tester:
- Julia version: 1.0.1
- Author: erathorn
- Date: 2019-05-07
=#

extensions = quote

    ## Load needed packages and import methods to be extended

    using Distributions
    import Distributions: minimum, maximum, logpdf

    ## Type declaration
    mutable struct PhyloDist <: ContinuousUnivariateDistribution
        my_tree
        mypi::Real
        data::Array
        #rates::Array
    end
    minimum(d::PhyloDist) = -Inf
    maximum(d::PhyloDist) = Inf

    function logpdf(d::PhyloDist, x::Real)
        rates = ones(3132)

        return MCPhylo.FelsensteinFunction(d.my_tree.value, d.data, d.mypi, rates,3132)
    end
end
#include("./myMamba.jl")
#using .myMamba
include("./MCPhylo/src/MCPhylo.jl")
using .MCPhylo




eval(extensions)
tt, data_arr, df = MCPhylo.make_tree_with_data_mat("./local/IE_Contemporary_Full.nex")
mt = MCPhylo.make_tree_with_data("./local/IE_Contemporary_Full.nex")

my_data = Dict{Symbol, Any}(
  :mtree => mt,
  :data =>data_arr)




model =  Model(
    y = Stochastic(1,
    (mtree, mypi, data) ->
    begin
        UnivariateDistribution[PhyloDist(mtree, mypi, data)]
    end,
    ),
    mypi = Stochastic(() -> Truncated(Uniform(0.0,1.0), 0.0, 1.0)),
    mtree = MCPhylo.StochasticT("t", () -> MCPhylo.CompoundDirichlet(1.0,1.0,0.100,1.0), true)
     )
inivals = rand(Uniform(0,1),3132)
inivals =inivals./sum(inivals)

inits = [ Dict(
    :mtree => my_data[:mtree],
    :mypi=> 0.5,
    :y => [-500000],
    :rates=>inivals)]

#scheme = [Slice(:mypi, 0.05), SliceSimplex(:rates)]
scheme = [Slice(:mypi, 0.05),
            #Slice(:blenvec, 0.02),
             MCPhylo.ProbPathHMCSampler(:mtree, 3.0,2.0)]

setsamplers!(model, scheme)


sim = mcmc(model, my_data, inits, 250, burnin=50, chains=1)

describe(sim)

using Profile
using ProfileView
using Serialization
function benchmark()
    # Any setup code goes here.

    # Run once, to force compilation.
    println("======================= First run:")
    #srand(666)
    @time mcmc(model, my_data, inits, 2, burnin=1, chains=1)

    # Run a second time, with profiling.
    println("\n\n======================= Second run:")
    #srand(666)
    Profile.init(delay=10.01)
    Profile.clear()
    Profile.clear_malloc_data()
    @profile @time mcmc(model, my_data, inits, 10, burnin=1, chains=1)

    # Write profile results to profile.bin.
    r = Profile.retrieve()
    f = open("profile.bin", "w")
    Serialization.serialize(f, r)
    close(f)
end
