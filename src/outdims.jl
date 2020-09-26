module NilNumber

using LinearAlgebra

"""
    Nil <: Number
Nil is a singleton type with a single instance `nil`. Unlike
`Nothing` and `Missing` it subtypes `Number`.
"""
struct Nil <: Number end

const nil = Nil()

Nil(::T) where T<:Number = nil

Base.float(::Type{Nil}) = Nil
Base.copy(::Nil) = nil
Base.abs2(::Nil) = nil
Base.sqrt(::Nil) = nil
Base.zero(::Type{Nil}) = nil
Base.one(::Type{Nil}) = nil

Base.:+(::Nil) = nil
Base.:-(::Nil) = nil

Base.:+(::Nil, ::Nil) = nil
Base.:+(::Nil, ::Number) = nil
Base.:+(::Number, ::Nil) = nil

Base.:-(::Nil, ::Nil) = nil
Base.:-(::Nil, ::Number) = nil
Base.:-(::Number, ::Nil) = nil

Base.:*(::Nil, ::Nil) = nil
Base.:*(::Nil, ::Number) = nil
Base.:*(::Number, ::Nil) = nil

Base.:/(::Nil, ::Nil) = nil
Base.:/(::Nil, ::Number) = nil
Base.:/(::Number, ::Nil) = nil

Base.inv(::Nil) = nil

Base.isless(::Nil, ::Nil) = true
Base.isless(::Nil, ::Number) = true
Base.isless(::Number, ::Nil) = true

Base.abs(::Nil) = nil
Base.exp(::Nil) = nil

Base.typemin(::Type{Nil}) = nil
Base.typemax(::Type{Nil}) = nil
Base.:^(::Nil, ::Nil) = nil

# TODO: can this be shortened?
Base.promote(x::Nil, y::Nil) = (nil, nil)
Base.promote(x::Nil, y) = (nil, nil)
Base.promote(x, y::Nil) = (nil, nil)
Base.promote(x::Nil, y, z) = (nil, nil, nil)
Base.promote(x, y::Nil, z) = (nil, nil, nil)
Base.promote(x, y, z::Nil) = (nil, nil, nil)
Base.promote(x::Nil, y, z::Nil) = (nil, nil, nil)
Base.promote(x::Nil, y::Nil, z::Nil) = (nil, nil, nil)
Base.promote(x::Nil, y::Nil, z) = (nil, nil, nil)


LinearAlgebra.adjoint(::Nil) = nil
LinearAlgebra.transpose(::Nil) = nil

end  # module

using .NilNumber: Nil, nil

"""
    _handle_batchin(isize, dimsize)

Gracefully handle ignoring batch dimension by padding `isize` with a 1 if necessary.
Also returns a boolean indicating if the batch dimension was padded.

# Arguments:
- `isize`: the input size as specified by the user
- `dimsize`: the expected number of dimensions for this layer (including batch)
"""
function _handle_batchin(isize, dimsize)
  indims = length(isize)
  @assert isnothing(dimsize) || indims == dimsize || indims == dimsize - 1
    "outdims expects ndims(isize) == $dimsize (got isize = $isize). isize should be the size of the input to the function (with batch size optionally left off)"
  
  return (indims == dimsize || isnothing(dimsize)) ? (isize, false) : ((isize..., 1), true)
end

"""
    _handle_batchout(outsize, ispadded; preserve_batch = false)

Drop the batch dimension if requested.

# Arguments:
- `outsize`: the output size from a function
- `ispadded`: indicates whether the batch dimension in `outsize` is padded (see _handle_batchin)
- `preserve_batch`: set to `true` to always retain the batch dimension
"""
_handle_batchout(outsize, ispadded; preserve_batch = false) =
  (ispadded && !preserve_batch) ? outsize[1:(end - 1)] : outsize

"""
    outdims(m, isize; preserve_batch = false)

Calculate the output size of model/function `m` given an input of size `isize` (w/o computing results).
`isize` should include all dimensions (except batch dimension can be optionally excluded).
Set `preserve_batch = true` to retrain the output batch dimension even if `isize` excludes it.

*Note*: this method should work out of the box for custom layers.
"""
outdims(m, isize; preserve_batch = false) = with_logger(NullLogger()) do
    isize, ispadded = _handle_batchin(isize, dimhint(m))
    
    return _handle_batchout(size(m(fill(nil, isize))), ispadded; preserve_batch = preserve_batch)
end

## dimension hints

dimhint(m) = nothing
dimhint(m::Tuple) = dimhint(first(m))
dimhint(m::Chain) = dimhint(m.layers)
dimhint(::Dense) = 2
dimhint(::Diagonal) = 2
dimhint(m::Maxout) = dimhint(first(m.over))
dimhint(m::SkipConnection) = dimhint(m.layers)
dimhint(m::Conv) = ndims(m.weight)
dimhint(::ConvTranspose) = 4
dimhint(::DepthwiseConv) = 4
dimhint(::CrossCor) = 4
dimhint(::MaxPool) = 4
dimhint(::MeanPool) = 4
dimhint(::AdaptiveMaxPool) = 4
dimhint(::AdaptiveMeanPool) = 4
dimhint(::GlobalMaxPool) = 4
dimhint(::GlobalMeanPool) = 4


## fixes for layers that don't work out of the box

for (fn, Dims) in ((:conv, DenseConvDims), (:depthwiseconv, DepthwiseConvDims))
    @eval begin
        function NNlib.$fn(a::AbstractArray{<:Real}, b::AbstractArray{Nil}, dims::$Dims) where T
            NNlib.$fn(fill(nil, size(a)), b, dims)
        end

        function NNlib.$fn(a::AbstractArray{Nil}, b::AbstractArray{<:Real}, dims::$Dims) where T
            NNlib.$fn(a, fill(nil, size(b)), dims)
        end
    end
end
