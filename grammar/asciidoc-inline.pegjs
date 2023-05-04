{{
const { computeLocation, transformToModel, unshiftOntoCopy } = require('#inline-helpers')
const { splitLines } = require('#util')
}}
{
if (!input) return []
//const locations = options.locations ?? splitLines(input).reduce((accum, _, lineIdx) => {
//  const line = lineIdx + 1
//  accum[line] = { line, col: 1 }
//  return accum
//}, {})
const locations = options.locations
if (!/[`_*#:<[\\]/.test(input)) {
  // TODO extract the function to transform text and call it directly
  return transformToModel([input], computeLocation.bind(null, peg$computeLocation, locations))
}
}
// TODO instead of &any check here, could patch parser to node call parsenode() if peg$currPos === input.length
root = nodes:(&any @node)*
  {
    return transformToModel(nodes, computeLocation.bind(null, peg$computeLocation, locations))
  }

//node = span / macro / other
node = other_left / span / macro / other_right

// Q: should we rename span to marked?
span = code / emphasis / strong / open

code = unconstrained_code / constrained_code

emphasis = unconstrained_emphasis / constrained_emphasis

strong = unconstrained_strong / constrained_strong

open = unconstrained_open / constrained_open

macro = xref_shorthand / url_macro

unconstrained_code = pre:($wordy+)? main:('``' contents:(!'``' @constrained_code / emphasis / strong / open / macro / unconstrained_code_other)+ '``' { return { name: 'span', type: 'inline', variant: 'code', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

// Q: is it faster to use '`' !'`' / [_*#] here?
unconstrained_code_other = $(wordy ('`' !'`' / '_' / '*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'``')) / [^`]

unconstrained_emphasis = pre:($wordy+)? main:('__' contents:(code / !'__' @constrained_emphasis / strong / open / macro / unconstrained_emphasis_other)+ '__' { return { name: 'span', type: 'inline', variant: 'emphasis', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

unconstrained_emphasis_other = $(wordy ('`' / '_' !'_' / '*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'__')) / [^_]

unconstrained_strong = pre:($wordy+)? main:('**' contents:(code / emphasis / !'**' @constrained_strong / open / macro / unconstrained_strong_other)+ '**' { return { name: 'span', type: 'inline', variant: 'strong', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

// should first rule use wordy, wordy*, or wordy+ ?
// NOTE without &'**' check, parser ends up advancing character by character
unconstrained_strong_other = $(wordy ('`' / '_' / '*' !'*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'**')) / [^*]

unconstrained_open = pre:($wordy+)? main:('##' contents:(code / emphasis / strong / !'##' @constrained_open / macro / unconstrained_open_other)+ '##' { return { name: 'span', type: 'inline', variant: 'mark', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

unconstrained_open_other = $(wordy ('`' / '_' / '*' / '#' !'#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'##')) / [^#]

constrained_code = '`' !space contents0:(unconstrained_code / emphasis / strong / open / macro / @'`' !wordy / constrained_code_other) contents1:(unconstrained_code / emphasis / strong / macro / constrained_code_other)* '`' !wordy
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'code', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_code_other = $(wordy* constrained_left_mark_in_code) / $(not_mark_or_space+ (space not_mark_or_space+)* &('`' !wordy)) / $(space+ (!'`' / &'``' &unconstrained_code / '`')) / @'`' &wordy / escaped / [^ `]

constrained_emphasis = '_' !space contents0:(code / unconstrained_emphasis / strong / open / macro / @'_' !wordy / constrained_emphasis_other) contents1:(code / unconstrained_emphasis / strong / macro / constrained_emphasis_other)* '_' !wordy
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'emphasis', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_emphasis_other = $(wordy* constrained_left_mark_in_emphasis) / $(not_mark_or_space+ (space not_mark_or_space+)* &('_' !wordy)) / $(space+ (!'_' / &'__' &unconstrained_emphasis / '_')) / @'_' &wordy / escaped / [^ _]

constrained_strong = '*' !space contents0:(code / emphasis / unconstrained_strong / open / macro / @'*' !wordy / constrained_strong_other) contents1:(code / emphasis / unconstrained_strong / macro / constrained_strong_other)* '*' !wordy
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'strong', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

// NOTE can never take space before * unless we're sure it's an unconstrained strong or the closing mark for the constrained strong
// NOTE instead of checking &unconstrained_strong, could use wordy_or_space+ for unconstrained pre; but it's slow
constrained_strong_other = $(wordy* constrained_left_mark_in_strong) / $(not_mark_or_space+ (space not_mark_or_space+)* &('*' !wordy)) / $(space+ (!'*' / &'**' &unconstrained_strong / '*')) / @'*' &wordy / escaped / [^ *]

constrained_open = '#' !space contents0:(code / emphasis / strong / unconstrained_open / macro / @'#' !wordy / constrained_open_other) contents1:(code / emphasis / strong / unconstrained_open / macro / constrained_open_other)* '#' !wordy
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'mark', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_open_other = $(wordy* constrained_left_mark_in_open) / $(not_mark_or_space+ (space not_mark_or_space+)* &('#' !wordy)) / $(space+ (!'#' / &'##' &unconstrained_open / '#')) / @'#' &wordy / escaped / [^ #]

// FIXME: xref_shorthand_other prevents search for span following text (e.g., *foo* and *bar*)
// Q: should we use !space at start of target?
xref_shorthand = '<<' target:(!space @$[^,>]+) linktext:(',' space? @grab_offset @(span / xref_shorthand_other)+)? '>>'
  {
    const [mark, contents] = linktext ?? [offset() + 2 + target.length, []]
    return { name: 'ref', type: 'inline', variant: 'xref', target, range: Object.assign(range(), { inlinesStart: mark }), inlines: contents }
  }

xref_shorthand_other = match:$[^>]+

// FIXME attrlist_other prevents search for span following text (e.g., *foo* and *bar*)
// TODO implement attrlist following optional link text
url_macro = protocol:('link:' @'' / @('https://' / 'http://')) target:$macro_target '[' mark:grab_offset contents:(span / attrlist_other)* ']'
  {
    return { name: 'ref', type: 'inline', variant: 'link', target: protocol + target, range: Object.assign(range(), { inlinesStart: mark }), inlines: contents }
  }

macro_target = !space @[^\[]+

attrlist_other = match:$[^\]]+

other_left = $(not_mark_or_space+ (space / colon? !any))+
other_right = $(wordy* constrained_left_mark) / space / escaped / any

// TODO could add : to regexp and use wordy+ colon in second alternative
escaped = '\\' match:([`_*<] / $(wordy* colon))
  {
    return Object.assign(new String(match), { escaped: true, sourceLength: match.length + 1 })
  }

wordy = [\p{Alpha}0-9]

// NOTE we don't have to include \\ here since it's always paired with a mark (if it means something)
not_mark_or_space = [^ `_*#:<\\]

// NOTE regex starts to become faster than alternatives at ~ 3 characters
constrained_left_mark = [`_*#]
//constrained_left_mark = '`' / '_' / '*' / '#'

constrained_left_mark_in_code = '_' / '*' / '#'

constrained_left_mark_in_emphasis = '`' / '*' / '#'

constrained_left_mark_in_strong = '`' / '_' / '#'

constrained_left_mark_in_open = '`' / '_' / '*'

grab_offset = ''
  {
    return offset()
  }

colon = ':'

space = ' '

any = .
