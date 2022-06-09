#################### No-U-Turn Sampler ####################

#################### Types and Constructors ####################

mutable struct NUTSTune <: SamplerTune
  logf::Union{Function, Missing}
  adapt::Bool
  alpha::Float64
  epsilon::Float64
  epsilonbar::Float64
  gamma::Float64
  Hbar::Float64
  kappa::Float64
  m::Int
  mu::Float64
  nalpha::Int
  t0::Float64
  target::Float64
  tree_depth::Int

  NUTSTune() = new()

  function NUTSTune(x::Vector, epsilon::Real, logfgrad::Union{Function, Missing};
                    target::Real=0.6, tree_depth::Int=10)
    new(logfgrad, false, 0.0, epsilon, 1.0, 0.05, 0.0, 0.75, 0, NaN, 0, 10.0,
        target, tree_depth)
  end
end


const NUTSVariate = Sampler{NUTSTune, T} where T


#################### Sampler Constructor ####################

function NUTS_classical(params::ElementOrVector{Symbol}; epsilon::Real = -Inf, kwargs...)
  tune = NUTSTune(Float64[], epsilon, logpdfgrad!; kwargs...)
  Sampler(Float64[], params, tune, Symbol[], true)
end


#################### Sampling Functions ####################

#sample!(v::NUTSVariate; args...) = sample!(v, v.tune.logfgrad; args...)
"""
    sample!(v::NUTSVariate, logfgrad::Function; adapt::Bool=false)

Draw one sample from a target distribution using the NUTS sampler. Parameters
are assumed to be continuous and unconstrained.

Returns `v` updated with simulated values and associated tuning parameters.
"""
function sample!(v::NUTSVariate{T}, logfgrad::Function; adapt::Bool=false, kwargs...) where T<: AbstractArray{<: Real}
  tune = v.tune
  
  if tune.m == 0 && isinf(tune.epsilon)
    tune.epsilon = nutsepsilon(v.value, logfgrad, tune.target)
  end
  setadapt!(v, adapt)
  if tune.adapt
    tune.m += 1
    nuts_sub!(v, tune.epsilon, logfgrad)
    p = 1.0 / (tune.m + tune.t0)
    ada = tune.alpha / tune.nalpha
    ada = ada > 1 ? 1.0 : ada
    tune.Hbar = (1.0 - p) * tune.Hbar +
                p * (tune.target - ada)
    tune.epsilon = exp(tune.mu - sqrt(tune.m) * tune.Hbar / tune.gamma)
    p = tune.m^-tune.kappa
    tune.epsilonbar = exp(p * log(tune.epsilon) +
                          (1.0 - p) * log(tune.epsilonbar))
  else
    if (tune.m > 0) tune.epsilon = tune.epsilonbar end
    nuts_sub!(v, tune.epsilon, logfgrad)
  end
  v
end


function setadapt!(v::NUTSVariate{T}, adapt::Bool) where T<: AbstractArray{<: Real}
  tune = v.tune
  if adapt && !tune.adapt
    tune.m = 0
    tune.mu = log(10.0 * tune.epsilon)
  end
  tune.adapt = adapt
  v
end


function nuts_sub!(v::NUTSVariate{T}, epsilon::Real, logfgrad::Function) where T<: AbstractArray{<: Real}
  n = length(v)
  x = deepcopy(v.value)
  logf, grad = logfgrad(x)
  r = randn(n)
  
  logp0 = logf - 0.5 * dot(r, r)
  logu0 = logp0 + log(rand())
  xminus = xplus = deepcopy(x)
  rminus = rplus = deepcopy(r)
  gradminus = gradplus = deepcopy(grad)
  j = 0
  n = 1
  s = true
  while s && j < v.tune.tree_depth
    pm = 2 * (rand() > 0.5) - 1
    if pm == -1
      xminus, rminus, gradminus, _, _, _, xprime, nprime, sprime, alpha,
        nalpha = buildtree(xminus, rminus, gradminus, pm, j, epsilon, logfgrad,
                           logp0, logu0)
    else
      _, _, _, xplus, rplus, gradplus, xprime, nprime, sprime, alpha, nalpha =
        buildtree(xplus, rplus, gradplus, pm, j, epsilon, logfgrad, logp0,
                  logu0)
    end
    if sprime && rand() < nprime / n
      v[:] = xprime
    end
    j += 1
    n += nprime
    s = sprime && nouturn(xminus, xplus, rminus, rplus)
    v.tune.alpha, v.tune.nalpha = alpha, nalpha
  end
  v
end


function leapfrog(x::Vector{Float64}, r::Vector{Float64}, grad::Vector{Float64},
                  epsilon::Real, logfgrad::Function)
  r += (0.5 * epsilon) * grad
  x += epsilon * r
  logf, grad = logfgrad(x)
  r += (0.5 * epsilon) * grad
  x, r, logf, grad
end


function buildtree(x::Vector{Float64}, r::Vector{Float64},
                   grad::Vector{Float64}, pm::Integer, j::Integer,
                   epsilon::Real, logfgrad::Function, logp0::Real, logu0::Real)
  if j == 0
    xprime, rprime, logfprime, gradprime = leapfrog(x, r, grad, pm * epsilon,
                                                    logfgrad)
    logpprime = logfprime - 0.5 * dot(rprime, rprime)
    nprime = Int(logu0 < logpprime)
    sprime = logu0 < logpprime + 1000.0
    xminus = xplus = xprime
    rminus = rplus = rprime
    gradminus = gradplus = gradprime
    alphaprime = min(1.0, exp(logpprime - logp0))
    alphaprime = isnan(alphaprime) ? 0.0 : alphaprime
    nalphaprime = 1
  else
    xminus, rminus, gradminus, xplus, rplus, gradplus, xprime, nprime, sprime,
      alphaprime, nalphaprime = buildtree(x, r, grad, pm, j - 1, epsilon,
                                          logfgrad, logp0, logu0)
    if sprime
      if pm == -1
        xminus, rminus, gradminus, _, _, _, xprime2, nprime2, sprime2,
          alphaprime2, nalphaprime2 = buildtree(xminus, rminus, gradminus, pm,
                                                j - 1, epsilon, logfgrad, logp0,
                                                logu0)
      else
        _, _, _, xplus, rplus, gradplus, xprime2, nprime2, sprime2,
          alphaprime2, nalphaprime2 = buildtree(xplus, rplus, gradplus, pm,
                                                j - 1, epsilon, logfgrad, logp0,
                                                logu0)
      end
      if rand() < nprime2 / (nprime + nprime2)
        xprime = xprime2
      end
      nprime += nprime2
      sprime = sprime2 && nouturn(xminus, xplus, rminus, rplus)
      alphaprime += alphaprime2
      nalphaprime += nalphaprime2
    end
  end
  xminus, rminus, gradminus, xplus, rplus, gradplus, xprime, nprime, sprime,
    alphaprime, nalphaprime
end


function nouturn(xminus::Vector{Float64}, xplus::Vector{Float64},
                 rminus::Vector{Float64}, rplus::Vector{Float64})
  xdiff = xplus - xminus
  turbo_dot(xdiff, rminus) >= 0 && turbo_dot(xdiff, rplus) >= 0
end