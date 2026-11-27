# SPDX-FileCopyrightText: © 2026 Michael Goerz <mail@michaelgoerz.net>
#
# SPDX-License-Identifier: MIT OR CC0-1.0

# Diagrams of the control structures in QuantumPropagators and QuantumControl.
#
# There are two identical copies of this file:
#
#   QuantumPropagators.jl/docs/control_diagrams.jl
#   QuantumControl.jl/docs/control_diagrams.jl
#
# with the stylesheet
#
#   QuantumPropagators.jl/docs/src/assets/control_diagrams.css
#   QuantumControl.jl/docs/src/assets/control_diagrams.css
#
# Any change must be made in both packages, so that `diff` of the two copies
# prints nothing. The file declares the full diagrams. QuantumPropagators
# shows the top half of each diagram, QuantumControl the full diagram.
#
# Usage, in `docs/make.jl`:
#
#     include("control_diagrams.jl")  # defines the module `ControlDiagrams`
#
# and in a page:
#
#     ```@example control-diagrams
#     using Main.ControlDiagrams: diagram, legend  # hide
#     legend(:parameters; part=:top)  # hide
#     ```
#
#     ```@example control-diagrams
#     diagram(:parameters_generator; part=:top)  # hide
#     ```
#
# with `part=:top` for the top half and `part=:full` for the full diagram.
# The available diagrams are `:parameters_generator`, `:parameters_custom`,
# and `:control_functions`; the available legends are `:parameters` and
# `:functions`. The result of `diagram` or `legend` is shown as an inline
# `<svg>` element (`MIME"text/html"`). Since the colors come from the
# stylesheet, an SVG file or an `<img>` tag would not work.

module ControlDiagrams

export diagram, legend


#### Data types ###############################################################

# Every element is tagged with the half of the diagram it belongs to, `:top`
# or `:bottom`. Coordinates are in the units of the `viewBox` of the SVG. The
# `class` of an element is a CSS class in `control_diagrams.css`.

"""A rounded box with a title and a subtitle, e.g., a generator or a control.

The title is in the line above the vertical center, the subtitle (e.g., the
type) below it.
"""
struct Box
    class::String  # "gen", "amp", "ctl", "val"
    x::Float64
    y::Float64
    width::Float64
    height::Float64
    title::String
    subtitle::String
end

"""A vector of values: a parameter block (`class="blk"`) or a pulse (`"pul"`).

The `title` is above a row of cells of equal width, with the labels in
`cells`.
"""
struct Block
    class::String  # "blk", "pul"
    x::Float64
    y::Float64
    width::Float64
    height::Float64
    title::String
    cells::Vector{String}
end

"""An `ArrayPartition`: an outer box with one frame per parameter block.

The `frames` are `(x, width)` of each block. The `cells` are `(x, label)`
for the indices, the `separators` are the `x` of the dotted lines between
cells. The `label` is written below the box, centered at `label_x`.
"""
struct Partition
    x::Float64
    y::Float64
    width::Float64
    height::Float64
    frames::Vector{Tuple{Float64,Float64}}
    cells::Vector{Tuple{Float64,String}}
    separators::Vector{Float64}
    label_x::Float64
    label::String
end

"""A background rectangle that groups some boxes."""
struct Group
    x::Float64
    y::Float64
    width::Float64
    height::Float64
end

"""An arrow along the SVG path `d`, with an arrow head at the end.

The `class` determines the kind of arrow: `"ref"` (contains or holds),
`"alias"` (aliases), `"gp"` (results in, via a method). With `head=false`,
the path has no arrow head, e.g., because it joins another arrow.
"""
struct Arrow
    class::String
    d::String
    head::Bool
end

Arrow(class, d; head = true) = Arrow(class, d, head)

"""A text label at position `x`, `y`.

The `anchor` is the SVG `text-anchor` (`"start"`, `"middle"`, `"end"`). A
label with `rotate=true` runs from bottom to top, centered at `x`, `y`.
"""
struct Label
    class::String
    x::Float64
    y::Float64
    text::String
    anchor::String
    rotate::Bool
end

Label(class, x, y, text; anchor = "middle", rotate = false) =
    Label(class, x, y, text, anchor, rotate)

const Element = Union{Box,Block,Partition,Group,Arrow,Label}

"""The declaration of a diagram.

The `height` and `description` (for screen readers) are given for the top
half and for the full diagram.
"""
struct DiagramSpec
    width::Float64
    height_top::Float64
    height_full::Float64
    description_top::String
    description_full::String
    elements::Vector{Pair{Symbol,Element}}  # half => element
end

"""An entry in a legend: a swatch (`class` of the CSS) and a description.

The `kind` of swatch is `:box` (a small box), `:pulse` (a box with cells),
`:arrow`, or `:method` (an arrow labeled "method"). An entry with `half =
:bottom` appears only in the legend of the full diagrams.
"""
struct LegendEntry
    kind::Symbol
    class::String
    description::String  # HTML
    half::Symbol
end

LegendEntry(kind, class, description) = LegendEntry(kind, class, description, :top)


#### Data #####################################################################

const DIAGRAMS = Dict{Symbol,DiagramSpec}()

# Control parameters, for the built-in `Generator`
DIAGRAMS[:parameters_generator] = DiagramSpec(
    860,
    392,
    690,
    "A built-in Generator H and, connected by get_parameters, the ArrayPartition that aliases the blocks u and v. H contains the amplitudes a1 = eps1 + eps2 and a2 = eps2 + eps3, which contain the controls eps1, eps2, eps3. Controls eps1 and eps2 hold the same ComponentVector block u; eps3 holds the Vector block v.",
    "Top half: A built-in Generator H and, connected by get_parameters, the ArrayPartition that aliases the blocks u and v. H contains the amplitudes a1 = eps1 + eps2 and a2 = eps2 + eps3, which contain the controls eps1, eps2, eps3. Controls eps1 and eps2 hold the same ComponentVector block u; eps3 holds the Vector block v. Below the blocks are the derivatives of the controls: four derivative controls that hold u, and, grouped, the numbers 0.0 and 1.0 and the plain function t to t. Bottom half: get_parameter_deriv(H, u, 1) returns the Generator dH/domega, which contains the amplitude da1/domega and the control deps2/domega. Connected by get_parameters, dH/domega has its own ArrayPartition, with the block u as its only partition, which aliases u.",
    [
        :top =>
            Box("gen", 90, 20, 300, 54, "H = Ĥ₀ + a₁(t) Ĥ₁ + a₂(t) Ĥ₂", ":: Generator"),
        :top => Arrow("gp", "M390 47 H554"),
        :top => Label("gpl", 472, 41, "get_parameters"),
        :top => Partition(
            560,
            28,
            231.99,
            38,
            [(566, 129.99), (699.99, 86)],
            [(587.7, "1"), (631.03, "2"), (674.36, "3"), (721.49, "4"), (764.49, "5")],
            [609.33, 652.66, 742.99],
            676,
            "ArrayPartition"
        ),
        :top => Arrow("ref", "M220 74 L265 118"),
        :top => Arrow("ref", "M330 74 L530 118"),
        :top => Box("amp", 200, 120, 150, 40, "a₁ = ϵ₁ + ϵ₂", "amplitude"),
        :top => Box("amp", 470, 120, 150, 40, "a₂ = ϵ₂ + ϵ₃", "amplitude"),
        :top => Arrow("ref", "M240 160 L185 202"),
        :top => Arrow("ref", "M310 160 L410 202"),
        :top => Arrow("ref", "M515 160 L460 202"),
        :top => Arrow("ref", "M580 160 L680 202"),
        :top => Box(
            "ctl",
            60,
            204,
            210,
            48,
            "ϵ₁ = A₁ g(t) cos ωt",
            ":: ParameterizedFunction"
        ),
        :top => Box(
            "ctl",
            330,
            204,
            210,
            48,
            "ϵ₂ = A₂ g(t) cos ωt",
            ":: ParameterizedFunction"
        ),
        :top =>
            Box("ctl", 600, 204, 210, 48, "ϵ₃ = c₀ + c₁ t", ":: ParameterizedFunction"),
        :top => Arrow("ref", "M165 252 L250 303"),
        :top => Arrow("ref", "M435 252 L340 303"),
        :top => Arrow("ref", "M705 252 L705 303"),
        :top =>
            Block("blk", 200, 304, 180, 56, "u :: ComponentVector", ["ω", "A₁", "A₂"]),
        :top => Block("blk", 635, 304, 140, 56, "v :: Vector{Float64}", ["c₀", "c₁"]),
        :top => Arrow("alias", "M631 33 V8 H850 V374 H480 V344 H383"),
        :top => Label("al", 431, 338, "aliases u"),
        :top => Arrow("alias", "M786 47 H832 V332 H778"),
        :top => Label("al", 826, 294, "aliases v"; anchor = "end"),
        :bottom => Box("ctl", 56, 420, 158, 40, "∂ϵ₁/∂ω", ":: ParameterizedFunction"),
        :bottom => Box("ctl", 222, 420, 158, 40, "∂ϵ₂/∂ω", ":: ParameterizedFunction"),
        :bottom => Box("ctl", 388, 420, 158, 40, "∂ϵ₁/∂A₁", ":: ParameterizedFunction"),
        :bottom => Box("ctl", 554, 420, 158, 40, "∂ϵ₂/∂A₂", ":: ParameterizedFunction"),
        :bottom => Arrow("ref", "M135 420 L215 363"),
        :bottom => Arrow("ref", "M301 420 L255 363"),
        :bottom => Arrow("ref", "M467 420 L300 363"),
        :bottom => Arrow("ref", "M633 420 L345 363"),
        :bottom => Group(372, 470, 446, 56),
        :bottom =>
            Box("val", 380, 478, 182, 40, "∂ϵ₁/∂A₂ = ∂ϵ₂/∂A₁ = 0.0", ":: Float64"),
        :bottom => Box("val", 570, 478, 110, 40, "∂ϵ₃/∂c₀ = 1.0", ":: Float64"),
        :bottom => Box("ctl", 688, 478, 122, 40, "∂ϵ₃/∂c₁ = t ↦ t", ":: Function"),
        :bottom =>
            Box("amp", 90, 540, 230, 40, "∂a₁/∂ω = ∂ϵ₁/∂ω + ∂ϵ₂/∂ω", "amplitude"),
        :bottom => Arrow("ref", "M170 540 L140 462"),
        :bottom => Arrow("ref", "M260 540 L296 462"),
        :bottom => Box(
            "gen",
            70,
            610,
            300,
            54,
            "∂H/∂ω = (∂a₁/∂ω) Ĥ₁ + (∂ϵ₂/∂ω) Ĥ₂",
            ":: Generator"
        ),
        :bottom => Arrow("ref", "M205 610 L205 582"),
        :bottom => Arrow("ref", "M345 610 L330 462"),
        :bottom => Arrow("gp", "M90 41 H28 V646 H66"),
        :bottom => Label("gpl", 22, 340, "get_parameter_deriv(H, u, 1)"; rotate = true),
        :bottom => Arrow("gp", "M370 637 H524"),
        :bottom => Label("gpl", 447, 631, "get_parameters"),
        :bottom => Partition(
            530,
            618,
            142,
            38,
            [(536, 130)],
            [(557.67, "1"), (601, "2"), (644.33, "3")],
            [579.33, 622.67],
            601,
            "ArrayPartition"
        ),
        :bottom => Arrow("alias", "M666 637 H850 V374"; head = false),
    ]
)

# Control parameters, for a custom generator type
DIAGRAMS[:parameters_custom] = DiagramSpec(
    860,
    306,
    566,
    "A custom generator G of type TransmonGenerator and, connected by get_parameters, the ArrayPartition that aliases the blocks w and z. G holds the ComponentVector block w with the drift parameters nu and alpha, and contains a separately built Gaussian control eps4 that holds the block z.",
    "Top half: A custom generator G of type TransmonGenerator and, connected by get_parameters, the ArrayPartition that aliases the blocks w and z. G holds the ComponentVector block w with the drift parameters nu and alpha, and contains a separately built Gaussian control eps4 that holds the block z. Below z are the three derivative controls of eps4, which hold z. Bottom row: get_parameter_deriv(G, z, 2) returns the Generator dG/dsigma, which contains the control deps4/dsigma. Next to it, connected by get_parameters, dG/dsigma has its own ArrayPartition, with the block z as its only partition, which aliases z. Below dG/dsigma, the derivatives of G with respect to nu and alpha are Operators.",
    [
        :top => Box(
            "gen",
            70,
            20,
            330,
            54,
            "G = ν b†b + (α/2) b†b†bb + ϵ₄(t)(b + b†)",
            ":: TransmonGenerator"
        ),
        :top => Arrow("gp", "M400 47 H554"),
        :top => Label("gpl", 478, 41, "get_parameters"),
        :top => Partition(
            560,
            28,
            231.66,
            38,
            [(566, 86.66), (656.66, 129)],
            [(587.7, "1"), (631.03, "2"), (678.16, "3"), (721.16, "4"), (764.16, "5")],
            [609.33, 699.66, 742.66],
            706,
            "ArrayPartition"
        ),
        :top => Arrow("ref", "M200 74 L245 118"),
        :top => Label("s", 234, 100, "contains"; anchor = "start"),
        :top => Arrow("ref", "M370 74 L560 218"),
        :top => Label("s", 462, 150, "holds"; anchor = "end"),
        :top => Box(
            "ctl",
            150,
            120,
            230,
            48,
            "ϵ₄ = A exp(−(t−t₀)²/2σ²)",
            ":: GaussianControl"
        ),
        :top => Arrow("ref", "M265 168 L265 219"),
        :top =>
            Block("blk", 175, 220, 180, 56, "z :: ComponentVector", ["A", "σ", "t₀"]),
        :top => Block("blk", 539, 220, 140, 56, "w :: ComponentVector", ["ν", "α"]),
        :top => Arrow("alias", "M609 61 V218"),
        :top => Label("al", 617, 150, "aliases w"; anchor = "start"),
        :top => Arrow("alias", "M786 47 H850 V290 H480 V260 H358"),
        :top => Label("al", 419, 254, "aliases z"),
        :bottom => Box("ctl", 56, 336, 158, 40, "∂ϵ₄/∂A", ":: ParameterizedFunction"),
        :bottom => Box("ctl", 222, 336, 158, 40, "∂ϵ₄/∂σ", ":: ParameterizedFunction"),
        :bottom => Box("ctl", 388, 336, 158, 40, "∂ϵ₄/∂t₀", ":: ParameterizedFunction"),
        :bottom => Arrow("ref", "M135 336 L215 279"),
        :bottom => Arrow("ref", "M301 336 L265 279"),
        :bottom => Arrow("ref", "M467 336 L315 279"),
        :bottom =>
            Box("gen", 201, 416, 200, 54, "∂G/∂σ = (b + b†) ∂ϵ₄/∂σ", ":: Generator"),
        :bottom => Arrow("ref", "M301 416 L301 378"),
        :bottom => Box("val", 201, 500, 140, 54, "∂G/∂ν = b†b", ":: Operator"),
        :bottom => Box("val", 351, 500, 170, 54, "∂G/∂α = b†b†bb/2", ":: Operator"),
        :bottom => Arrow("gp", "M70 41 H28 V452 H197"),
        :bottom => Label("gpl", 22, 246, "get_parameter_deriv(G, z, 2)"; rotate = true),
        :bottom => Arrow("gp", "M401 443 H524"),
        :bottom => Label("gpl", 462, 437, "get_parameters"),
        :bottom => Partition(
            530,
            424,
            142,
            38,
            [(536, 130)],
            [(557.67, "1"), (601, "2"), (644.33, "3")],
            [579.33, 622.67],
            601,
            "ArrayPartition"
        ),
        :bottom => Arrow("alias", "M666 443 H850 V290"; head = false),
    ]
)

# Control functions, for the built-in `Generator`
DIAGRAMS[:control_functions] = DiagramSpec(
    890,
    384,
    616,
    "The Generator H = H0 + eps1(t) H1 + a2(t) H2 + a3(t) H3. evaluate turns H into an Operator H0 + sum of c_l H_l, the amplitude a3 into a Float64, and the control eps3 into a Float64. H contains the control eps1 directly as its amplitude, the ShapedAmplitude a2 = S(t) eps2(t), and the non-linear amplitude a3 = eps3(t) squared; these contain the Function controls eps1, eps2, eps3. discretize_on_midpoints turns each control into a pulse, a Vector{Float64} on the N_T midpoints.",
    "Top half: The Generator H = H0 + eps1(t) H1 + a2(t) H2 + a3(t) H3. evaluate turns H into an Operator H0 + sum of c_l H_l, the amplitude a3 into a Float64, and the control eps3 into a Float64. H contains the control eps1 directly as its amplitude, the ShapedAmplitude a2 = S(t) eps2(t), and the non-linear amplitude a3 = eps3(t) squared; these contain the Function controls eps1, eps2, eps3. discretize_on_midpoints turns each control into a pulse, a Vector{Float64} on the N_T midpoints. Bottom half: get_control_deriv(H, eps_l) gives dH/deps1 = H1, a static Matrix; dH/deps2 = S(t) H2, a Generator over a LockedAmplitude without controls; and dH/deps3 = 2 eps3(t) H3, a Generator over an amplitude that contains eps3. evaluate turns the last one into an Operator.",
    [
        :top => Box(
            "gen",
            210,
            20,
            300,
            54,
            "H = Ĥ₀ + ϵ₁(t) Ĥ₁ + a₂(t) Ĥ₂ + a₃(t) Ĥ₃",
            ":: Generator"
        ),
        :top => Arrow("gp", "M510 47 H706"),
        :top => Label("gpl", 608, 41, "evaluate"),
        :top => Box("val", 712, 20, 166, 54, "Ĥ₀ + Σₗ cₗ Ĥₗ", ":: Operator"),
        :top => Arrow("ref", "M250 74 L160 206"),
        :top => Arrow("ref", "M360 74 L360 118"),
        :top => Arrow("ref", "M470 74 L560 118"),
        :top => Box("amp", 280, 120, 160, 44, "a₂ = S(t) ϵ₂(t)", ":: ShapedAmplitude"),
        :top => Box("amp", 490, 120, 160, 44, "a₃ = ϵ₃(t)²", "amplitude"),
        :top => Arrow("gp", "M650 142 H706"),
        :top => Label("gpl", 679, 136, "evaluate"),
        :top => Box("val", 712, 120, 166, 44, "c₃ = ϵ₃(tₙ)²", ":: Float64"),
        :top => Arrow("ref", "M360 164 L360 206"),
        :top => Arrow("ref", "M570 164 L570 206"),
        :top => Box("ctl", 70, 208, 160, 48, "ϵ₁(t)", ":: Function"),
        :top => Box("ctl", 280, 208, 160, 48, "ϵ₂(t)", ":: Function"),
        :top => Box("ctl", 490, 208, 160, 48, "ϵ₃(t)", ":: Function"),
        :top => Arrow("gp", "M650 232 H706"),
        :top => Label("gpl", 679, 226, "evaluate"),
        :top => Box("val", 712, 208, 166, 48, "ϵ₃(tₙ)", ":: Float64"),
        :top => Arrow("gp", "M204 256 V310"),
        :top => Label("gpl", 197, 288, "discretize_on_midpoints"; anchor = "end"),
        :top => Arrow("gp", "M414 256 V310"),
        :top => Label("gpl", 407, 288, "discretize_on_midpoints"; anchor = "end"),
        :top => Arrow("gp", "M624 256 V310"),
        :top => Label("gpl", 617, 288, "discretize_on_midpoints"; anchor = "end"),
        :top => Block(
            "pul",
            70,
            314,
            150,
            54,
            "p₁ :: Vector{Float64}",
            ["1", "2", "3", "⋯", "N_T"]
        ),
        :top => Block(
            "pul",
            280,
            314,
            150,
            54,
            "p₂ :: Vector{Float64}",
            ["1", "2", "3", "⋯", "N_T"]
        ),
        :top => Block(
            "pul",
            490,
            314,
            150,
            54,
            "p₃ :: Vector{Float64}",
            ["1", "2", "3", "⋯", "N_T"]
        ),
        :bottom => Box("amp", 280, 420, 160, 44, "S(t)", ":: LockedAmplitude"),
        :bottom => Box("amp", 480, 420, 150, 44, "2ϵ₃(t)", "amplitude"),
        :bottom => Arrow("ref", "M630 442 H645 V259"),
        :bottom => Box("val", 70, 510, 160, 54, "∂H/∂ϵ₁ = Ĥ₁", ":: Matrix{ComplexF64}"),
        :bottom => Box("gen", 280, 510, 160, 54, "∂H/∂ϵ₂ = S(t) Ĥ₂", ":: Generator"),
        :bottom => Box("gen", 475, 510, 165, 54, "∂H/∂ϵ₃ = 2ϵ₃(t) Ĥ₃", ":: Generator"),
        :bottom => Arrow("ref", "M360 510 L360 466"),
        :bottom => Arrow("ref", "M555 510 L555 466"),
        :bottom => Arrow("gp", "M640 537 H706"),
        :bottom => Label("gpl", 673, 531, "evaluate"),
        :bottom => Box("val", 712, 510, 166, 54, "2ϵ₃(tₙ) Ĥ₃", ":: Operator"),
        :bottom => Arrow("gp", "M210 47 H28 V600 H555 V568"),
        :bottom => Arrow("gp", "M150 600 V568"),
        :bottom => Arrow("gp", "M360 600 V568"),
        :bottom => Label("gpl", 22, 330, "get_control_deriv(H, ϵₗ)"; rotate = true),
    ]
)

const LEGENDS = Dict{Symbol,Vector{LegendEntry}}()

LEGENDS[:parameters] = [
    LegendEntry(:box, "gen", "generator"),
    LegendEntry(:box, "amp", "amplitude"),
    LegendEntry(:box, "ctl", "control"),
    LegendEntry(:box, "blk", "parameter block"),
    LegendEntry(:box, "compo", "<code>ArrayPartition</code>"),
    LegendEntry(:box, "val", "number or operator", :bottom),
    LegendEntry(:arrow, "ref", "contains or holds"),
    LegendEntry(:arrow, "alias", "aliases"),
    LegendEntry(:method, "gp", "results in, via method"),
]

LEGENDS[:functions] = [
    LegendEntry(:box, "gen", "generator"),
    LegendEntry(:box, "amp", "amplitude"),
    LegendEntry(:box, "ctl", "control"),
    LegendEntry(:pulse, "pul", "pulse"),
    LegendEntry(:box, "val", "number or operator"),
    LegendEntry(:arrow, "ref", "contains"),
    LegendEntry(:method, "gp", "results in, via method"),
]


#### Rendering ################################################################

# Numbers are written without a trailing `.0`
fmt(x::Real) = isinteger(x) ? string(Int(x)) : string(Float64(x))

function esc(s::AbstractString)
    return replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

# The arrow head (marker) for each class of `Arrow`
const MARKERS = Dict("ref" => "n", "alias" => "a", "gp" => "gp")

function markers(id)
    return string(
        "<defs>",
        "<marker id=\"$id-n\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M0,0 L10,5 L0,10 z\" class=\"mk-n\"/></marker>",
        "<marker id=\"$id-a\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M0,0 L10,5 L0,10 z\" class=\"mk-a\"/></marker>",
        "<marker id=\"$id-gp\" viewBox=\"0 0 10 10\" refX=\"8\" refY=\"5\" markerWidth=\"4.6\" markerHeight=\"4.6\" orient=\"auto\"><path d=\"M0,0 L10,5 L0,10 z\" class=\"mk-gp\"/></marker>",
        "</defs>"
    )
end

rect(
    class,
    x,
    y,
    w,
    h,
    rx
) = "<rect class=\"$class\" x=\"$(fmt(x))\" y=\"$(fmt(y))\" width=\"$(fmt(w))\" height=\"$(fmt(h))\" rx=\"$(fmt(rx))\"/>"

text(
    class,
    x,
    y,
    s;
    anchor = "middle"
) = "<text class=\"$class\" x=\"$(fmt(x))\" y=\"$(fmt(y))\" text-anchor=\"$anchor\">$(esc(s))</text>"

line(
    class,
    x1,
    y1,
    x2,
    y2
) = "<line class=\"$class\" x1=\"$(fmt(x1))\" y1=\"$(fmt(y1))\" x2=\"$(fmt(x2))\" y2=\"$(fmt(y2))\"/>"

function svg(e::Box, id)
    xc = e.x + e.width / 2
    yt = e.y + e.height / 2 - 2
    return string(
        rect(e.class, e.x, e.y, e.width, e.height, 6),
        text("t", xc, yt, e.title),
        text("s", xc, yt + 15, e.subtitle)
    )
end

# Vertical offsets in a `Block`: title, line below the title, cell labels;
# and the CSS classes of the title, the cell lines, and the cell labels
const BLOCK_STYLE = Dict(
    "blk" => (title = 17, rule = 24, cells = 45, ct = "bt", cl = "cell", cc = "t"),
    "pul" => (title = 16, rule = 23, cells = 43, ct = "pt", cl = "pcell", cc = "s"),
)

function svg(e::Block, id)
    st = BLOCK_STYLE[e.class]
    parts = [
        rect(e.class, e.x, e.y, e.width, e.height, 6),
        text(st.ct, e.x + e.width / 2, e.y + st.title, e.title),
        line(st.cl, e.x, e.y + st.rule, e.x + e.width, e.y + st.rule),
    ]
    w = e.width / length(e.cells)
    for (k, label) in enumerate(e.cells)
        if k > 1
            xs = e.x + (k - 1) * w
            push!(parts, line(st.cl, xs, e.y + st.rule, xs, e.y + e.height))
        end
        push!(parts, text(st.cc, e.x + (k - 0.5) * w, e.y + st.cells, label))
    end
    return join(parts)
end

function svg(e::Partition, id)
    parts = [rect("compo", e.x, e.y, e.width, e.height, 5)]
    for (x, w) in e.frames
        push!(parts, rect("compf", x, e.y + 5, w, e.height - 10, 7))
    end
    items = vcat(
        [(x, text("s", x, e.y + 23, label)) for (x, label) in e.cells],
        [(x, line("compc", x, e.y + 8, x, e.y + e.height - 8)) for x in e.separators],
    )
    append!(parts, last.(sort(items; by = first)))
    push!(parts, text("at", e.label_x, e.y + 56, e.label))
    return join(parts)
end

svg(e::Group, id) = rect("grp", e.x, e.y, e.width, e.height, 9)

function svg(e::Arrow, id)
    if e.head
        return "<path class=\"$(e.class)\" d=\"$(e.d)\" marker-end=\"url(#$id-$(MARKERS[e.class]))\"/>"
    else
        return "<path class=\"$(e.class)\" d=\"$(e.d)\"/>"
    end
end

function svg(e::Label, id)
    if e.rotate
        return string(
            "<g transform=\"translate($(fmt(e.x)) $(fmt(e.y))) rotate(-90)\">",
            text(e.class, 0, 0, e.text; anchor = e.anchor),
            "</g>"
        )
    else
        return text(e.class, e.x, e.y, e.text; anchor = e.anchor)
    end
end


"""A rendered diagram or legend, shown as inline `<svg>` elements in HTML."""
struct Diagram
    html::String
end

Base.show(io::IO, ::MIME"text/html", d::Diagram) = print(io, d.html)

Base.show(io::IO, d::Diagram) = print(io, "Diagram(…)")


function _check_part(part)
    if part ∉ (:top, :full)
        throw(ArgumentError("`part` must be `:top` or `:full`, not $(repr(part))"))
    end
end


"""Render a diagram.

```julia
d = diagram(name; part=:top)
```

returns the diagram `name` (`:parameters_generator`, `:parameters_custom`,
`:control_functions`) as a `Diagram`, which shows as an inline `<svg>`
element in HTML. With `part=:top`, only the top half of the diagram is shown;
with `part=:full`, the entire diagram. The `id` is the prefix for the ids of
the arrow heads in the SVG, which must be unique on a page.
"""
function diagram(name::Symbol; part = :top, id = "cd-$name-$part")
    _check_part(part)
    spec = DIAGRAMS[name]
    full = (part == :full)
    height = full ? spec.height_full : spec.height_top
    description = full ? spec.description_full : spec.description_top
    lines = String[
        "<div class=\"control-diagram-figure\">",
        "<svg class=\"control-diagram\" viewBox=\"0 0 $(fmt(spec.width)) $(fmt(height))\" role=\"img\" aria-label=\"$(esc(description))\">",
        markers(id),
    ]
    for (half, element) in spec.elements
        if full || (half == :top)
            push!(lines, svg(element, id))
        end
    end
    push!(lines, "</svg>", "</div>")
    return Diagram(join(lines, "\n"))
end


function svg(entry::LegendEntry, id)
    c = entry.class
    if entry.kind == :box
        swatch = string(
            "<svg viewBox=\"0 0 44 16\" aria-hidden=\"true\">",
            rect(c, 3, 2, 38, 12, 3),
            "</svg>"
        )
    elseif entry.kind == :pulse
        swatch = string(
            "<svg viewBox=\"0 0 44 16\" aria-hidden=\"true\">",
            rect(c, 3, 2, 38, 12, 3),
            line("pcell", 16, 2, 16, 14),
            line("pcell", 28, 2, 28, 14),
            "</svg>"
        )
    elseif entry.kind == :arrow
        swatch = string(
            "<svg viewBox=\"0 0 44 16\" aria-hidden=\"true\">",
            markers(id),
            svg(Arrow(c, "M2 8 H40"), id),
            "</svg>"
        )
    elseif entry.kind == :method
        swatch = string(
            "<svg class=\"wide\" viewBox=\"0 0 64 26\" aria-hidden=\"true\">",
            markers(id),
            text("gpl", 30, 10, "method"),
            svg(Arrow(c, "M3 18 H58"), id),
            "</svg>"
        )
    else
        error("Unknown kind of legend entry: $(entry.kind)")
    end
    return "<span>$swatch$(entry.description)</span>"
end


"""Render a legend.

```julia
l = legend(name; part=:top)
```

returns the legend `name` (`:parameters`, `:functions`), which shows as a row
of inline `<svg>` elements in HTML. With `part=:top`, the legend includes only
the entries for the top halves of the diagrams; with `part=:full`, all
entries.
"""
function legend(name::Symbol; part = :top, id = "cd-legend-$name-$part")
    _check_part(part)
    lines =
        String["<div class=\"control-diagram control-diagram-legend\" aria-label=\"Legend\">"]
    for (k, entry) in enumerate(LEGENDS[name])
        if (part == :full) || (entry.half == :top)
            push!(lines, svg(entry, "$id-$k"))
        end
    end
    push!(lines, "</div>")
    return Diagram(join(lines, "\n"))
end

end
