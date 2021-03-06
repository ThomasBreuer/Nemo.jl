###############################################################################
#
#   nf_elem.jl : Antic number fields
#
###############################################################################

export AnticNumberField, nf_elem, norm, trace, CyclotomicField,
       MaximalRealSubfield, add!, sub!, mul!, signature, sqr_classical

###############################################################################
#
#   Type and parent object methods
#
###############################################################################

parent_type(::Type{nf_elem}) = AnticNumberField

doc"""
    parent(a::nf_elem)
> Return the parent of the given number field element.
"""
parent(a::nf_elem) = a.parent

elem_type(::Type{AnticNumberField}) = nf_elem

doc"""
    base_ring(a::AnticNumberField)
> Returns `Union{}` since a number field doesn't depend on any ring.
"""
base_ring(a::AnticNumberField) = Union{}

doc"""
    base_ring(a::nf_elem)
> Returns `Union{}` since a number field doesn't depend on any ring.
"""
base_ring(a::nf_elem) = Union{}

isdomain_type(::Type{nf_elem}) = true

doc"""
    var(a::AnticNumberField)
> Returns the identifier (as a symbol, not a string), that is used for printing
> the generator of the given number field.
"""
var(a::AnticNumberField) = a.S

function check_parent(a::nf_elem, b::nf_elem)
   a.parent != b.parent && error("Incompatible number field elements")
end

show_minus_one(::Type{nf_elem}) = false

###############################################################################
#
#   Basic manipulation
#
###############################################################################

const hash_seed = UInt==UInt64 ? 0xc2a44fbe466a1827 : 0xc2a44fb

function hash(a::nf_elem, h::UInt)
   global hash_seed
   b = hash_seed
   d = denominator(a)
   b = hash(d, b)
   for i in 1:degree(parent(a)) + 1
         num_coeff!(d, a, i)
         b = xor(b, xor(hash(d, h), h))
         b = (b << 1) | (b >> (sizeof(Int)*8 - 1))
   end
   return b
end

doc"""
    coeff(x::nf_elem, n::Int)
> Return the $n$-th coefficient of the polynomial representation of the given
> number field element. Coefficients are numbered from $0$, starting with the
> constant coefficient.
"""
function coeff(x::nf_elem, n::Int)
   n < 0 && throw(DomainError())
   z = fmpq()
   ccall((:nf_elem_get_coeff_fmpq, :libflint), Void,
     (Ref{fmpq}, Ref{nf_elem}, Int, Ref{AnticNumberField}), z, x, n, parent(x))
   return z
end

function num_coeff!(z::fmpz, x::nf_elem, n::Int)
   n < 0 && throw(DomainError())
   ccall((:nf_elem_get_coeff_fmpz, :libflint), Void,
     (Ref{fmpz}, Ref{nf_elem}, Int, Ref{AnticNumberField}), z, x, n, parent(x))
   return z
end

doc"""
    gen(a::AnticNumberField)
> Return the generator of the given number field.
"""
function gen(a::AnticNumberField)
   r = nf_elem(a)
   ccall((:nf_elem_gen, :libflint), Void,
         (Ref{nf_elem}, Ref{AnticNumberField}), r, a)
   return r
end

doc"""
    one(a::AnticNumberField)
> Return the multiplicative identity, i.e. one, in the given number field.
"""
function one(a::AnticNumberField)
   r = nf_elem(a)
   ccall((:nf_elem_one, :libflint), Void,
         (Ref{nf_elem}, Ref{AnticNumberField}), r, a)
   return r
end

doc"""
    zero(a::AnticNumberField)
> Return the multiplicative identity, i.e. one, in the given number field.
"""
function zero(a::AnticNumberField)
   r = nf_elem(a)
   ccall((:nf_elem_zero, :libflint), Void,
         (Ref{nf_elem}, Ref{AnticNumberField}), r, a)
   return r
end

doc"""
    isgen(a::nf_elem)
> Return `true` if the given number field element is the generator of the
> number field, otherwise return `false`.
"""
function isgen(a::nf_elem)
   return ccall((:nf_elem_is_gen, :libflint), Bool,
                (Ref{nf_elem}, Ref{AnticNumberField}), a, a.parent)
end

doc"""
    isone(a::nf_elem)
> Return `true` if the given number field element is the multiplicative
> identity of the number field, i.e. one, otherwise return `false`.
"""
function isone(a::nf_elem)
   return ccall((:nf_elem_is_one, :libflint), Bool,
                (Ref{nf_elem}, Ref{AnticNumberField}), a, a.parent)
end

doc"""
    iszero(a::nf_elem)
> Return `true` if the given number field element is the additive
> identity of the number field, i.e. zero, otherwise return `false`.
"""
function iszero(a::nf_elem)
   return ccall((:nf_elem_is_zero, :libflint), Bool,
                (Ref{nf_elem}, Ref{AnticNumberField}), a, a.parent)
end

doc"""
    isunit(a::nf_elem)
> Return `true` if the given number field element is invertible, i.e. nonzero,
> otherwise return `false`.
"""
isunit(a::nf_elem) = a != 0

doc"""
    denominator(a::nf_elem)
> Return the denominator of the polynomial representation of the given number
> field element.
"""
function denominator(a::nf_elem)
   z = fmpz()
   ccall((:nf_elem_get_den, :libflint), Void,
         (Ref{fmpz}, Ref{nf_elem}, Ref{AnticNumberField}),
         z, a, a.parent)
   return z
end

function elem_from_mat_row(a::AnticNumberField, b::fmpz_mat, i::Int, d::fmpz)
   Generic._checkbounds(rows(b), i) || throw(BoundsError())
   cols(b) == degree(a) || error("Wrong number of columns")
   z = a()
   ccall((:nf_elem_set_fmpz_mat_row, :libflint), Void,
        (Ref{nf_elem}, Ref{fmpz_mat}, Int, Ref{fmpz}, Ref{AnticNumberField}),
        z, b, i - 1, d, a)
   return z
end

function elem_to_mat_row!(a::fmpz_mat, i::Int, d::fmpz, b::nf_elem)
   ccall((:nf_elem_get_fmpz_mat_row, :libflint), Void,
         (Ref{fmpz_mat}, Int, Ref{fmpz}, Ref{nf_elem}, Ref{AnticNumberField}),
         a, i - 1, d, b, b.parent)
   nothing
 end

doc"""
    degree(a::AnticNumberField)
> Return the degree of the given number field, i.e. the degree of its
> defining polynomial.
"""
degree(a::AnticNumberField) = degree(a.pol)

doc"""
    signature(a::AnticNumberField)
> Return the signature of the given number field, i.e. a tuple $r, s$
> consisting of $r$, the number of real embeddings and $s$, half the number of
> complex embeddings.
"""
signature(a::AnticNumberField) = signature(a.pol)

function deepcopy_internal(d::nf_elem, dict::ObjectIdDict)
   z = nf_elem(parent(d), d)
   return z
end

###############################################################################
#
#   AbstractString I/O
#
###############################################################################

function show(io::IO, a::AnticNumberField)
   print(io, "Number field over Rational Field")
   print(io, " with defining polynomial ", a.pol)
end

function show(io::IO, x::nf_elem)
   cstr = ccall((:nf_elem_get_str_pretty, :libflint), Ptr{UInt8},
                (Ref{nf_elem}, Ptr{UInt8}, Ref{AnticNumberField}),
                 x, string(var(parent(x))), parent(x))
   s = unsafe_string(cstr)
   ccall((:flint_free, :libflint), Void, (Ptr{UInt8},), cstr)

   s = replace(s, "/", "//")

   print(io, s)

end

needs_parentheses(::Nemo.nf_elem) = true

isnegative(::nf_elem) = false

###############################################################################
#
#   Unary operators
#
###############################################################################

function -(a::nf_elem)
   r = a.parent()
   ccall((:nf_elem_neg, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, a.parent)
   return r
end

###############################################################################
#
#   Binary operators
#
###############################################################################

function +(a::nf_elem, b::nf_elem)
   check_parent(a, b)
   r = a.parent()
   ccall((:nf_elem_add, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function -(a::nf_elem, b::nf_elem)
   check_parent(a, b)
   r = a.parent()
   ccall((:nf_elem_sub, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function *(a::nf_elem, b::nf_elem)
   check_parent(a, b)
   r = a.parent()
   ccall((:nf_elem_mul, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

###############################################################################
#
#   Ad hoc binary operators
#
###############################################################################

function +(a::nf_elem, b::Int)
   r = a.parent()
   ccall((:nf_elem_add_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function +(a::nf_elem, b::fmpz)
   r = a.parent()
   ccall((:nf_elem_add_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function +(a::nf_elem, b::fmpq)
   r = a.parent()
   ccall((:nf_elem_add_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function -(a::nf_elem, b::Int)
   r = a.parent()
   ccall((:nf_elem_sub_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function -(a::nf_elem, b::fmpz)
   r = a.parent()
   ccall((:nf_elem_sub_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function -(a::nf_elem, b::fmpq)
   r = a.parent()
   ccall((:nf_elem_sub_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function -(a::Int, b::nf_elem)
   r = b.parent()
   ccall((:nf_elem_si_sub, :libflint), Void,
         (Ref{nf_elem}, Int, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, b.parent)
   return r
end

function -(a::fmpz, b::nf_elem)
   r = b.parent()
   ccall((:nf_elem_fmpz_sub, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpz}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, b.parent)
   return r
end

function -(a::fmpq, b::nf_elem)
   r = b.parent()
   ccall((:nf_elem_fmpq_sub, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpq}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, b.parent)
   return r
end

+(a::nf_elem, b::Integer) = a + fmpz(b)

-(a::nf_elem, b::Integer) = a - fmpz(b)

-(a::Integer, b::nf_elem) = fmpz(a) - b

+(a::Integer, b::nf_elem) = b + a

+(a::fmpq, b::nf_elem) = b + a

+(a::Rational, b::nf_elem) = fmpq(a) + b

+(a::nf_elem, b::Rational) = b + a

-(a::Rational, b::nf_elem) = fmpq(a) - b

-(a::nf_elem, b::Rational) = a - fmpq(b)

function *(a::nf_elem, b::Int)
   r = a.parent()
   ccall((:nf_elem_scalar_mul_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function *(a::nf_elem, b::fmpz)
   r = a.parent()
   ccall((:nf_elem_scalar_mul_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function *(a::nf_elem, b::fmpq)
   r = a.parent()
   ccall((:nf_elem_scalar_mul_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function *(a::Rational, b::nf_elem)
  return fmpq(a) * b
end

*(a::nf_elem, b::Rational) = b*a

*(a::Integer, b::nf_elem) = b * a

*(a::fmpz, b::nf_elem) = b * a

*(a::fmpq, b::nf_elem) = b * a

//(a::nf_elem, b::Int) = divexact(a, b)

//(a::nf_elem, b::fmpz) = divexact(a, b)

//(a::nf_elem, b::Integer) = a//fmpz(b)

//(a::nf_elem, b::fmpq) = divexact(a, b)

//(a::Integer, b::nf_elem) = divexact(a, b)

//(a::fmpz, b::nf_elem) = divexact(a, b)

//(a::fmpq, b::nf_elem) = divexact(a, b)

//(a::Rational, b::nf_elem) = divexact(fmpq(a), b)

//(a::nf_elem, b::Rational) = divexact(a, fmpq(b))

###############################################################################
#
#   Powering
#
###############################################################################

function ^(a::nf_elem, n::Int)
   r = a.parent()
   ccall((:nf_elem_pow, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         r, a, abs(n), a.parent)
   if n < 0
      r = inv(r)
   end
   return r
end

###############################################################################
#
#   Comparison
#
###############################################################################

function ==(a::nf_elem, b::nf_elem)
   check_parent(a, b)
   return ccall((:nf_elem_equal, :libflint), Bool,
           (Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}), a, b, a.parent)
end

###############################################################################
#
#   Ad hoc comparison
#
###############################################################################

==(a::nf_elem, b::Integer) = a == parent(a)(b)

==(a::nf_elem, b::fmpz) = a == parent(a)(b)

==(a::nf_elem, b::fmpq) = a == parent(a)(b)

==(a::Integer, b::nf_elem) = parent(b)(a) == b

==(a::fmpz, b::nf_elem) = parent(b)(a) == b

==(a::fmpq, b::nf_elem) = parent(b)(a) == b

###############################################################################
#
#   Inversion
#
###############################################################################

doc"""
    inv(a::nf_elem)
> Return $a^{-1}$. Requires $a \neq 0$.
"""
function inv(a::nf_elem)
   iszero(a) && throw(DivideError())
   r = a.parent()
   ccall((:nf_elem_inv, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, a.parent)
   return r
end

###############################################################################
#
#   Exact division
#
###############################################################################

function divexact(a::nf_elem, b::nf_elem)
   iszero(b) && throw(DivideError())
   check_parent(a, b)
   r = a.parent()
   ccall((:nf_elem_div, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

###############################################################################
#
#   Ad hoc exact division
#
###############################################################################

function divexact(a::nf_elem, b::Int)
   b == 0 && throw(DivideError())
   r = a.parent()
   ccall((:nf_elem_scalar_div_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

function divexact(a::nf_elem, b::fmpz)
   iszero(b) && throw(DivideError())
   r = a.parent()
   ccall((:nf_elem_scalar_div_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

divexact(a::nf_elem, b::Integer) = divexact(a, fmpz(b))

function divexact(a::nf_elem, b::fmpq)
   iszero(b) && throw(DivideError())
   r = a.parent()
   ccall((:nf_elem_scalar_div_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         r, a, b, a.parent)
   return r
end

divexact(a::Integer, b::nf_elem) = inv(b)*a

divexact(a::fmpz, b::nf_elem) = inv(b)*a

divexact(a::fmpq, b::nf_elem) = inv(b)*a

###############################################################################
#
#   Removal and valuation
#
###############################################################################

doc"""
    divides(f::nf_elem, g::nf_elem)
> Returns a pair consisting of a flag which is set to `true` if $g$ divides
> $f$ and `false` otherwise, and a number field element $h$ such that $f = gh$
> if such exists. If not, the value of $h$ is undetermined.
"""
function divides(a::nf_elem, b::nf_elem)
  iszero(b) && throw(DivideError())
   return true, divexact(a, b)
end

###############################################################################
#
#   Norm and trace
#
###############################################################################

doc"""
    norm(a::nf_elem)
> Return the absolute norm of $a$. The result will be a rational number.
"""
function norm(a::nf_elem)
   z = fmpq()
   ccall((:nf_elem_norm, :libflint), Void,
         (Ref{fmpq}, Ref{nf_elem}, Ref{AnticNumberField}),
         z, a, a.parent)
   return z
end

doc"""
    norm(a::nf_elem)
> Return the absolute trace of $a$. The result will be a rational number.
"""
function trace(a::nf_elem)
   z = fmpq()
   ccall((:nf_elem_trace, :libflint), Void,
         (Ref{fmpq}, Ref{nf_elem}, Ref{AnticNumberField}),
         z, a, a.parent)
   return z
end

###############################################################################
#
#   Unsafe functions
#
###############################################################################

function zero!(a::nf_elem)
   ccall((:nf_elem_zero, :libflint), Void,
         (Ref{nf_elem}, Ref{AnticNumberField}), a, parent(a))
   return a
end

function mul!(z::nf_elem, x::nf_elem, y::nf_elem)
   ccall((:nf_elem_mul, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
                                                  z, x, y, parent(x))
   return z
end

function mul_red!(z::nf_elem, x::nf_elem, y::nf_elem, red::Bool)
   ccall((:nf_elem_mul_red, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}, Cint),
                                                z, x, y, parent(x), red)
   return z
end

function addeq!(z::nf_elem, x::nf_elem)
   ccall((:nf_elem_add, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
                                                  z, z, x, parent(x))
   return z
end

function add!(a::nf_elem, b::nf_elem, c::nf_elem)
   ccall((:nf_elem_add, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{nf_elem}, Ref{AnticNumberField}),
         a, b, c, a.parent)
  return a
end

function reduce!(x::nf_elem)
   ccall((:nf_elem_reduce, :libflint), Void,
         (Ref{nf_elem}, Ref{AnticNumberField}), x, parent(x))
   return x
end

###############################################################################
#
#   Ad hoc unsafe functions
#
###############################################################################

function add!(c::nf_elem, a::nf_elem, b::fmpq)
   ccall((:nf_elem_add_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function add!(c::nf_elem, a::nf_elem, b::fmpz)
   ccall((:nf_elem_add_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function add!(c::nf_elem, a::nf_elem, b::Int)
   ccall((:nf_elem_add_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

add!(c::nf_elem, a::nf_elem, b::Integer) = add!(c, a, fmpz(b))

function sub!(c::nf_elem, a::nf_elem, b::fmpq)
   ccall((:nf_elem_sub_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function sub!(c::nf_elem, a::nf_elem, b::fmpz)
   ccall((:nf_elem_sub_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function sub!(c::nf_elem, a::nf_elem, b::Int)
   ccall((:nf_elem_sub_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

sub!(c::nf_elem, a::nf_elem, b::Integer) = sub!(c, a, fmpz(b))

function sub!(c::nf_elem, a::fmpq, b::nf_elem)
   ccall((:nf_elem_fmpq_sub, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpq}, Ref{nf_elem}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function sub!(c::nf_elem, a::fmpz, b::nf_elem)
   ccall((:nf_elem_fmpz_sub, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpz}, Ref{nf_elem}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function sub!(c::nf_elem, a::Int, b::nf_elem)
   ccall((:nf_elem_si_sub, :libflint), Void,
         (Ref{nf_elem}, Int, Ref{nf_elem}, Ref{AnticNumberField}),
         c, a, b, b.parent)
   return c
end

sub!(c::nf_elem, a::Integer, b::nf_elem) = sub!(c, fmpz(a), b)

function mul!(c::nf_elem, a::nf_elem, b::fmpq)
   ccall((:nf_elem_scalar_mul_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function mul!(c::nf_elem, a::nf_elem, b::fmpz)
   ccall((:nf_elem_scalar_mul_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

function mul!(c::nf_elem, a::nf_elem, b::Int)
   ccall((:nf_elem_scalar_mul_si, :libflint), Void,
         (Ref{nf_elem}, Ref{nf_elem}, Int, Ref{AnticNumberField}),
         c, a, b, a.parent)
   return c
end

mul!(c::nf_elem, a::nf_elem, b::Integer) = mul!(c, a, fmpz(b))

###############################################################################
#
#   Speedups for polynomials over number fields
#
###############################################################################

function sqr_classical(a::Generic.Poly{nf_elem})
   lena = length(a)

   t = base_ring(a)()

   lenz = 2*lena - 1
   d = Array{nf_elem}(lenz)

   for i = 1:lena - 1
      d[2i - 1] = base_ring(a)()
      d[2i] = base_ring(a)()
      d[2i - 1] = mul_red!(d[2i - 1], coeff(a, i - 1), coeff(a, i - 1), false)
   end
   d[2*lena - 1] = base_ring(a)()
   d[2*lena - 1] = mul_red!(d[2*lena - 1], coeff(a, lena - 1), coeff(a, lena - 1), false)

   for i = 1:lena
      for j = i + 1:lena
         t = mul_red!(t, coeff(a, i - 1), coeff(a, j - 1), false)
         d[i + j - 1] = addeq!(d[i + j - 1], t)
         d[i + j - 1] = addeq!(d[i + j - 1], t)
      end
   end

   for i = 1:lenz
      d[i] = reduce!(d[i])
   end

   z = parent(a)(d)

   set_length!(z, normalise(z, lenz))

   return z
end

function mul_classical(a::Generic.Poly{nf_elem}, b::Generic.Poly{nf_elem})
   check_parent(a, b)
   lena = length(a)
   lenb = length(b)

   if lena == 0 || lenb == 0
      return parent(a)()
   end

   if a == b
       return sqr_classical(a)
   end

   t = base_ring(a)()

   lenz = lena + lenb - 1
   d = Array{nf_elem}(lenz)

   for i = 1:lena
      d[i] = base_ring(a)()
      d[i] = mul_red!(d[i], coeff(a, i - 1), coeff(b, 0), false)
   end

   for i = 2:lenb
      d[lena + i - 1] = base_ring(a)()
      d[lena + i - 1] = mul_red!(d[lena + i - 1], a.coeffs[lena], coeff(b, i - 1), false)
   end

   for i = 1:lena - 1
      for j = 2:lenb
         t = mul_red!(t, coeff(a, i - 1), b.coeffs[j], false)
         d[i + j - 1] = addeq!(d[i + j - 1], t)
      end
   end

   for i = 1:lenz
      d[i] = reduce!(d[i])
   end

   z = parent(a)(d)

   set_length!(z, normalise(z, lenz))

   return z
end

function *(a::Generic.Poly{nf_elem}, b::Generic.Poly{nf_elem})
   check_parent(a, b)
   lena = length(a)
   lenb = length(b)
   if min(lena, lenb) < 20
      return mul_classical(a, b)
   end
   lenr = lena + lenb - 1
   r = parent(a)()
   if lena == 0 || lenb == 0
      return r
   end
   pol = base_ring(a).pol
   K = base_ring(a)
   R = parent(pol)
   T = elem_type(R)
   S = Generic.PolyRing{T}(R, :y)
   f = S()
   fit!(f, lena)
   for i = 1:lena
      f = setcoeff!(f, i - 1, R(coeff(a, i - 1)))
   end
   set_length!(f, lena)
   if a !== b
      g = S()
      fit!(g, lenb)
      for i = 1:lenb
         g = setcoeff!(g, i - 1, R(coeff(b, i - 1)))
      end
      set_length!(g, lenb)
   else
      g = f
   end
   p = f*g
   fit!(r, lenr)
   for i = 1:lenr
      r.coeffs[i] = K(p.coeffs[i])
   end
   set_length!(r, normalise(r, lenr))
   return r
end

###############################################################################
#
#   Promotions
#
###############################################################################

promote_rule(::Type{nf_elem}, ::Type{T}) where {T <: Integer} = nf_elem

promote_rule(::Type{nf_elem}, ::Type{fmpz}) = nf_elem

promote_rule(::Type{nf_elem}, ::Type{fmpq}) = nf_elem

promote_rule(::Type{nf_elem}, ::Type{fmpq_poly}) = nf_elem

###############################################################################
#
#   Parent object call overloads
#
###############################################################################

function (a::AnticNumberField)()
   z = nf_elem(a)
   ccall((:nf_elem_set_si, :libflint), Void,
         (Ref{nf_elem}, Int, Ref{AnticNumberField}), z, 0, a)
   return z
end

function (a::AnticNumberField)(c::Int)
   z = nf_elem(a)
   ccall((:nf_elem_set_si, :libflint), Void,
         (Ref{nf_elem}, Int, Ref{AnticNumberField}), z, c, a)
   return z
end

(a::AnticNumberField)(c::Integer) = a(fmpz(c))

function (a::AnticNumberField)(c::fmpz)
   z = nf_elem(a)
   ccall((:nf_elem_set_fmpz, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpz}, Ref{AnticNumberField}), z, c, a)
   return z
end

function (a::AnticNumberField)(c::fmpq)
   z = nf_elem(a)
   ccall((:nf_elem_set_fmpq, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpq}, Ref{AnticNumberField}), z, c, a)
   return z
end

function (a::AnticNumberField)(b::nf_elem)
   parent(b) != a && error("Cannot coerce number field element")
   return b
end

function (a::AnticNumberField)(pol::fmpq_poly)
   pol = parent(a.pol)(pol) # check pol has correct parent
   z = nf_elem(a)
   if length(pol) >= length(a.pol)
      pol = mod(pol, a.pol)
   end
   ccall((:nf_elem_set_fmpq_poly, :libflint), Void,
         (Ref{nf_elem}, Ref{fmpq_poly}, Ref{AnticNumberField}), z, pol, a)
   return z
end

function (a::FmpqPolyRing)(b::nf_elem)
   parent(parent(b).pol) != a && error("Cannot coerce from number field to polynomial ring")
   r = a()
   ccall((:nf_elem_get_fmpq_poly, :libflint), Void,
         (Ref{fmpq_poly}, Ref{nf_elem}, Ref{AnticNumberField}), r, b, parent(b))
   return r
end

###############################################################################
#
#   AnticNumberField constructor
#
###############################################################################

doc"""
    NumberField(f::fmpq_poly, s::AbstractString)
> Return a tuple $R, x$ consisting of the parent object $R$ and generator $x$
> of the number field $\mathbb{Q}/(f)$ where $f$ is the supplied polynomial.
> The supplied string `s` specifies how the generator of the number field
> should be printed.
"""
function NumberField(f::fmpq_poly, s::AbstractString; cached = true)
   S = Symbol(s)
   parent_obj = AnticNumberField(f, S, cached)

   return parent_obj, gen(parent_obj)
end

doc"""
    CyclotomicField(n::Int, s::AbstractString, t = "\$")
> Return a tuple $R, x$ consisting of the parent object $R$ and generator $x$
> of the $n$-th cyclotomic field, $\mathbb{Q}(\zeta_n)$. The supplied string
> `s` specifies how the generator of the number field should be printed. If
> provided, the string `t` specifies how the generator of the polynomial ring
> from which the number field is constructed, should be printed. If it is not
> supplied, a default dollar sign will be used to represent the variable.
"""
function CyclotomicField(n::Int, s::AbstractString, t = "\$"; cached = true)
   Zx, x = PolynomialRing(FlintZZ, string(gensym()); cached = cached)
   Qx, = PolynomialRing(FlintQQ, t; cached = cached)
   f = cyclotomic(n, x)
   return NumberField(Qx(f), s; cached = cached)
end

doc"""
    MaximalRealSubfield(n::Int, s::AbstractString, t = "\$")
> Return a tuple $R, x$ consisting of the parent object $R$ and generator $x$
> of the totally real subfield of the $n$-th cyclotomic field,
> $\mathbb{Q}(\zeta_n)$. The supplied string `s` specifies how the generator of
> the number field should be printed. If provided, the string `t` specifies how
> the generator of the polynomial ring from which the number field is
> constructed, should be printed. If it is not supplied, a default dollar sign
> will be used to represent the variable.
"""
function MaximalRealSubfield(n::Int, s::AbstractString, t = "\$"; cached = true)
   Zx, x = PolynomialRing(FlintZZ, string(gensym()); cached = cached)
   Qx, = PolynomialRing(FlintQQ, t; cached = cached)
   f = cos_minpoly(n, x)
   return NumberField(Qx(f), s; cached = cached)
end
