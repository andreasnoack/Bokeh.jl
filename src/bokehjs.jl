using JSON

module Bokehjs

const RealVect  = Union{AbstractVector{Int}, AbstractVector{Float64}}
const RealMat   = Union{AbstractMatrix{Int}, AbstractMatrix{Float64}}
const RealArray = Union{RealMat, RealVect}
# would be nice to parameterize, but more important to constrain dims to 1 or 2
# RealArray{N} = Union{AbstractArray{Int, N}, AbstractArray{Float64, N}}

# like nothing except omitted from json rather than being null
mutable struct Omit
    v::AbstractString
    Omit() = new("__omitted from json__")
end
const omit = Omit()

# in case we want to restrict value types in future:
const BkAny      = Any # Union{Dict, Array, AbstractString, Number, Bool, Void, UUID}
const NullDict   = Union{Void, Dict{AbstractString, BkAny}}
const OmitDict   = Union{Omit, Dict{Symbol, BkAny}}
const NullString = Union{Void, AbstractString}
const OmitString = Union{Omit, AbstractString}
const NullSymbol = Union{Void, Symbol}
const OmitSymbol = Union{Omit, Symbol}
const NullFloat  = Union{Float64, Void}
const NullInt    = Union{Int, Void}

const uuid4 = Base.Random.uuid4
const UUID  = Base.Random.UUID

abstract type PlotObject end

abstract type BkRange <: PlotObject end

const NullBkRange = Union{Void, BkRange}

abstract type Renderer <: PlotObject end

abstract type Axis <: PlotObject end

mutable struct TypeID
    plotob::Union{PlotObject, Void}
end

function TypeID()
    TypeID(nothing)
end

mutable struct Plot <: PlotObject
    uuid::UUID
    title::AbstractString
    tools::Vector{BkAny}
    plot_height::Int
    plot_width::Int
    x_range::TypeID
    y_range::TypeID
    # could be Vector{TypeID}?:
    renderers::Vector{BkAny}
    above::Vector{TypeID}
    below::Vector{TypeID}
    left::Vector{TypeID}
    right::Vector{TypeID}
    data_sources::Vector{BkAny}
end

mutable struct ColumnDataSource <: PlotObject
    uuid::UUID
    column_names::Vector{Symbol}
    selected::Vector{Any}
    discrete_ranges::Dict{Symbol, BkAny}
    cont_ranges::Dict{Symbol, BkAny}
    data::Dict{Symbol, Vector}
end

function ColumnDataSource(data::Dict{Symbol, Vector})
    ColumnDataSource(uuid4(),
                     collect(keys(data)),
                     BkAny[],
                     Dict{Symbol, BkAny}(),
                     Dict{Symbol, BkAny}(),
                     data)
end

mutable struct DataRange1d <: BkRange
    uuid::UUID
    sources::Vector{BkAny}
end

function DataRange1d(cdss::Vector{ColumnDataSource}, columns::Vector{AbstractString})
    source(cds) = Dict{AbstractString, BkAny}("columns" => columns,
                                      "source" => TypeID(cds))
    sources = map(source, cdss)
    DataRange1d(uuid4(), sources)
end

mutable struct TickFormatter <: PlotObject
    uuid::UUID
    _type_name::Symbol
    format::OmitDict
    function TickFormatter(name::Symbol)
        @assert name in (:BasicTickFormatter, :DatetimeTickFormatter,
                         :LogTickFormatter)
        # format only seems to occur for DatetimeTickFormatter and even then is empty
        format = name == :DatetimeTickFormatter ? Dict{Symbol, BkAny}() : omit
        new(uuid4(), name, format)
    end
end

mutable struct Ticker <: PlotObject
    uuid::UUID
    _type_name::Symbol
    num_minor_ticks::Int64
    Ticker(name::Symbol) = new(uuid4(), name, 5)
end

mutable struct LinearAxis <: Axis
    uuid::UUID
    dimension::Int
    bounds::AbstractString
    location::AbstractString
    formatter::TypeID
    ticker::TypeID
    plot::TypeID
end

function LinearAxis(dimension::Int, tf::TickFormatter, t::Ticker, plot::Plot)
    LinearAxis(uuid4(),
               dimension,
               "auto",
               "min",
               TypeID(tf),
               TypeID(t),
               TypeID(plot))
end

mutable struct Grid <: Renderer
    uuid::UUID
    dimension::Int
    plot::TypeID
    ticker::TypeID
end

function Grid(dimension::Int, plot::Plot, ticker::Ticker)
    Grid(uuid4(), dimension, TypeID(plot), TypeID(ticker))
end

mutable struct Legend <: Renderer
    uuid::UUID
    plot::TypeID
    legends::Vector{Tuple}
    orientation::OmitSymbol
end

function Legend(plot::Plot, legends::Vector{Tuple})
    Legend(plot, legends, nothing)
end

function Legend(plot::Plot, legends::Vector{Tuple}, orientation::NullSymbol)
    orientation = orientation == nothing ? omit : orientation
    @assert orientation in (omit, :top_left, :top_center, :top_right,
                            :right_center, :bottom_right, :bottom_center,
                            :bottom_left, :left_center, :center)
    Legend(uuid4(),
           TypeID(plot),
           [(l, [TypeID(r)]) for (l, r) in legends],
           orientation)
end

mutable struct Glyph <: PlotObject
    uuid::UUID
    _type_name::Symbol
    line_color::OmitDict
    line_width::OmitDict
    line_alpha::OmitDict
    fill_color::OmitDict
    fill_alpha::OmitDict
    size::OmitDict
    line_dash::Union{Omit, Vector{Int64}}
    x::Dict{Symbol, Symbol}
    y::Dict{Symbol, Symbol}
end

mutable struct GlyphRenderer <: Renderer
    uuid::UUID
    data_source::TypeID
    nonselection_glyph::TypeID
    selection_glyph::TypeID
    glyph::TypeID
    name::Union{Void, AbstractString}
    server_data_source::NullDict
end

const NullGlyph = Union{Void, Glyph}

function GlyphRenderer(coldata::ColumnDataSource, nonsel_g::NullGlyph,
                       sel_g::NullGlyph, glyph::Glyph)
    GlyphRenderer(uuid4(),
                  TypeID(coldata),
                  TypeID(nonsel_g),
                  TypeID(sel_g),
                  TypeID(glyph),
                  nothing,
                  nothing
                 )
end

mutable struct Metatool <: PlotObject
    uuid::UUID
    _type_name::AbstractString
    plot::TypeID
    dimensions::Union{Vector{AbstractString}, Void, Omit}
end

function Metatool(typename::AbstractString, plot::Plot, dimensions)
    plot = TypeID(plot)
    Metatool(uuid4(), typename, plot, dimensions)
end

function Metatool(typename::AbstractString, plot::Plot)
    Metatool(typename, plot, omit)
end

# TODO: these are duplicated as HEIGHT and WIDTH in Bokeh.jl
_DEFAULT_HEIGHT = 600
_DEFAULT_WIDTH = 600

function Plot()
    Plot(uuid4(),
         "",
         Void[],
         _DEFAULT_HEIGHT,
         _DEFAULT_WIDTH,
         TypeID(),
         TypeID(),
         Void[],

         Void[],
         Void[],
         Void[],
         Void[],

         Void[]
        )
end

function Plot(plot::Plot,
              xrange::BkRange,
              yrange::BkRange,
              renderers::Array{PlotObject,1},
              axes,#::Dict{Symbol, Array{PlotObject,1}},
              tools::Array{PlotObject,1},
              title::AbstractString="Bokeh Plot",
              height::Int=_DEFAULT_HEIGHT,
              width::Int=_DEFAULT_WIDTH)
    data_sources = BkAny[]# [TypeID(coldata)]

    Plot(plot.uuid,
         title,
         map(TypeID, tools),
         height,
         width,
         TypeID(xrange),
         TypeID(yrange),
         map(TypeID, renderers),
         map(TypeID, axes[:above]),
         map(TypeID, axes[:below]),
         map(TypeID, axes[:left]),
         map(TypeID, axes[:right]),
         data_sources
        )
end

mutable struct PlotContext <: PlotObject
    uuid::UUID
    children::Vector{TypeID}
end

function PlotContext(plot::Plot)
    PlotContext(uuid4(),[TypeID(plot)])
end

end  # module

# extract useful types from Bokehjs module
const RealVect   = Bokehjs.RealVect
const RealMat    = Bokehjs.RealMat
const RealArray  = Bokehjs.RealArray
const BkAny      = Bokehjs.BkAny
const omit       = Bokehjs.omit
const Glyph      = Bokehjs.Glyph
const NullString = Bokehjs.NullString
const NullSymbol = Bokehjs.NullSymbol
const NullFloat  = Bokehjs.NullFloat
const NullInt    = Bokehjs.NullInt

JSON.lower(uuid::Bokehjs.UUID) = string(uuid)

function JSON.lower(tid::Bokehjs.TypeID)
    tid.plotob == nothing && return nothing
    attrs = fieldnames(tid.plotob)
    obtype = in(:_type_name, attrs) ? tid.plotob._type_name : typeof(tid.plotob)
    Dict{AbstractString, BkAny}("type" => obtype, "id" => tid.plotob.uuid)
end

JSON.lower(::Type{T}) where {T<:Bokehjs.PlotObject} = string(T.name.name)
