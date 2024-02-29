{{
const { computeLocation, transformToModel } = require('#inline-helpers')
const inlinePreprocessor = require('#inline-preprocessor')
const { splitLines, unshiftOntoCopy } = require('#util')
}}
{
if (!input) return []
const { attributes: documentAttributes = {}, locations, preprocessorMode } = options
let inputCorrection, preprocessedInput, sourceMapping
if (preprocessorMode !== 'none') {
  if ((sourceMapping = options.sourceMapping)) {
    let startOffset, endOffset
    if (Array.isArray((startOffset = sourceMapping[0].offset))) startOffset = startOffset[0]
    if (Array.isArray((endOffset = sourceMapping[sourceMapping.length - 1].offset))) endOffset = endOffset[1]
    if (startOffset || endOffset > startOffset + (input.length - 1)) {
      inputCorrection = { padStart: startOffset, padEnd: endOffset - (startOffset + (input.length - 1)) }
    }
  }
  ;({ input: preprocessedInput, sourceMapping } = inlinePreprocessor(input, { attributes: documentAttributes, mode: preprocessorMode, sourceMapping }))
  if (!preprocessedInput) return []
}
const offsetToSourceLocation = splitLines(input)
  .reduce((accum, lineVal, lineIdx, lines) => {
    const line = lineIdx + 1
    const location = locations ? locations[line] : { line, col: 1 }
    let col = location.col
    let stopCol = col + lineVal.length
    if (inputCorrection) {
      if (line === lines.length) stopCol += inputCorrection.padEnd
      if (!lineIdx) stopCol += inputCorrection.padStart
    }
    for (; col < stopCol; col++) accum.push(Object.assign({}, location, { col }))
    return accum
  }, [])
if (!/[`_*#:<[\\]/.test(sourceMapping ? (input = preprocessedInput) : input)) {
  if (sourceMapping) {
    if (~sourceMapping.findIndex((it) => it.pass)) {
      const sourceLength = preprocessedInput.length
      input = Object.assign(new String(input.replace(/\x10\0+/g, (_, idx) => sourceMapping[idx].contents)), { sourceLength })
    }
  }
  // TODO extract the function to transform a single text node and call it directly
  return transformToModel([input], computeLocation.bind(null, sourceMapping, offsetToSourceLocation))
}
}
// TODO instead of &any check here, could patch parser to node call parsenode() if peg$currPos === input.length
root = nodes:(&any @node)*
  {
    return transformToModel(nodes, computeLocation.bind(null, sourceMapping, offsetToSourceLocation))
  }

//node = span / macro / other
node = other_left / span / macro / other_right

// Q: should we rename span to marked?
span = code / emphasis / strong / open / saved_passthrough

code = unconstrained_code / constrained_code

emphasis = unconstrained_emphasis / constrained_emphasis

strong = unconstrained_strong / constrained_strong

open = unconstrained_open / constrained_open

macro = xref_shorthand / url_macro

unconstrained_code = pre:$(alpha_d alpha_d*)? main:('``' contents:(!'``' @constrained_code / emphasis / strong / open / macro / unconstrained_code_other)+ '``' { return { name: 'span', type: 'inline', variant: 'code', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

// Q: is it faster to use '`' !'`' / [_*#] here?
unconstrained_code_other = $(alpha_d ('`' !'`' / '_' / '*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'``')) / !'`' @.

unconstrained_emphasis = pre:$(alpha_d alpha_d*)? main:('__' contents:(code / !'__' @constrained_emphasis / strong / open / macro / unconstrained_emphasis_other)+ '__' { return { name: 'span', type: 'inline', variant: 'emphasis', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

unconstrained_emphasis_other = $(alpha_d ('`' / '_' !'_' / '*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'__')) / !'_' @.

unconstrained_strong = pre:$(alpha_d alpha_d*)? main:('**' contents:(code / emphasis / !'**' @constrained_strong / open / macro / unconstrained_strong_other)+ '**' { return { name: 'span', type: 'inline', variant: 'strong', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

// should first rule use alpha_d, alpha_d*, or alpha_d+ ?
// NOTE without &'**' check, parser ends up advancing character by character
unconstrained_strong_other = $(alpha_d ('`' / '_' / '*' !'*' / '#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'**')) / !'*' @.

unconstrained_open = pre:$(alpha_d alpha_d*)? main:('##' contents:(code / emphasis / strong / !'##' @constrained_open / macro / unconstrained_open_other)+ '##' { return { name: 'span', type: 'inline', variant: 'mark', form: 'unconstrained', range: Object.assign(range(), { inlinesStart: offset() + 2 }), inlines: contents } })
  {
    return pre ? [pre, main] : main
  }

unconstrained_open_other = $(alpha_d ('`' / '_' / '*' / '#' !'#')) / $(not_mark_or_space+ (space not_mark_or_space+)* (space+ / &'##')) / !'#' @.

constrained_code = '`' !space contents0:(unconstrained_code / emphasis / strong / open / macro / @'`' !alpha_d / saved_passthrough / constrained_code_other) contents1:(unconstrained_code / emphasis / strong / macro / saved_passthrough / constrained_code_other)* '`' !alpha_d
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'code', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_code_other = $(alpha_d* constrained_left_mark_in_code) / $(not_mark_or_space+ (space not_mark_or_space+)* &('`' !alpha_d)) / $(space+ (!'`' / &'``' &unconstrained_code / '`')) / @'`' &alpha_d / escaped / !(' ' / '`') @.

constrained_emphasis = '_' !space contents0:(code / unconstrained_emphasis / strong / open / macro / @'_' !alpha_d / constrained_emphasis_other) contents1:(code / unconstrained_emphasis / strong / macro / constrained_emphasis_other)* '_' !alpha_d
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'emphasis', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_emphasis_other = $(alpha_d* constrained_left_mark_in_emphasis) / $(not_mark_or_space+ (space not_mark_or_space+)* &('_' !alpha_d)) / $(space+ (!'_' / &'__' &unconstrained_emphasis / '_')) / @'_' &alpha_d / escaped / !(' ' / '_') @.

constrained_strong = '*' !space contents0:(code / emphasis / unconstrained_strong / open / macro / @'*' !alpha_d / constrained_strong_other) contents1:(code / emphasis / unconstrained_strong / macro / constrained_strong_other)* '*' !alpha_d
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'strong', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

// NOTE can never take space before * unless we're sure it's an unconstrained strong or the closing mark for the constrained strong
// NOTE instead of checking &unconstrained_strong, could use alpha_d_or_space+ for unconstrained pre; but it's slow
constrained_strong_other = $(alpha_d* constrained_left_mark_in_strong) / $(not_mark_or_space+ (space not_mark_or_space+)* &('*' !alpha_d)) / $(space+ (!'*' / &'**' &unconstrained_strong / '*')) / @'*' &alpha_d / escaped / !(' ' / '*') @.

constrained_open = '#' !space contents0:(code / emphasis / strong / unconstrained_open / macro / @'#' !alpha_d / constrained_open_other) contents1:(code / emphasis / strong / unconstrained_open / macro / constrained_open_other)* '#' !alpha_d
  {
    const contents = contents1.length ? unshiftOntoCopy(contents1, contents0) : [contents0]
    return { name: 'span', type: 'inline', variant: 'mark', form: 'constrained', range: Object.assign(range(), { inlinesStart: offset() + 1 }), inlines: contents }
  }

constrained_open_other = $(alpha_d* constrained_left_mark_in_open) / $(not_mark_or_space+ (space not_mark_or_space+)* &('#' !alpha_d)) / $(space+ (!'#' / &'##' &unconstrained_open / '#')) / @'#' &alpha_d / escaped / !(' ' / '#') @.

// FIXME: xref_shorthand_other prevents search for span following text (e.g., *foo* and *bar*)
// Q: should we use !space at start of target?
xref_shorthand = '<' '<' target:(!space @$[^,>]+) linktext:(',' space? @offset @(span / xref_shorthand_other)+)? '>' '>'
  {
    const [mark, contents] = linktext ?? [offset() + 2 + target.length, []]
    return { name: 'ref', type: 'inline', variant: 'xref', target, range: Object.assign(range(), { inlinesStart: mark }), inlines: contents }
  }

saved_passthrough = '\x10' '\0'+
  {
    const { start, end } = range()
    const contents = sourceMapping[start].contents
    return Object.assign(new String(contents), { pass: true, sourceLength: end - 1 - start })
  }

xref_shorthand_other = $[^>]+

// FIXME attrlist_other prevents search for span following text (e.g., *foo* and *bar*)
// TODO implement attrlist following optional link text
url_macro = protocol:('l' 'ink:' @'' / &'h' @('https://' / 'http://')) target:$macro_target '[' contentsOffset:offset contents:(span / attrlist_other)* ']'
  {
    // NOTE quick hack to support new window hint; if found, need to set window=_blank attribute on node
    let lastInline = contents[contents.length - 1]
    if (typeof lastInline === 'string' && lastInline[lastInline.length - 1] === '^') {
      contents.pop()
      if ((lastInline = lastInline.slice(0, -1))) contents.push(lastInline)
    }
    return { name: 'ref', type: 'inline', variant: 'link', target: protocol + target, range: Object.assign(range(), { inlinesStart: contentsOffset }), inlines: contents }
  }

macro_target = !space @[^\[]+

attrlist_other = $[^\]]+

other_left = $(not_mark_or_space+ (space / colon? !any))+
other_right = $(alpha_d* constrained_left_mark) / space / escaped / any

// TODO could add : to regexp and use alpha_d+ colon in second alternative
escaped = '\\' match:([`_*#<{+\\] / $(alpha_d* colon))
  {
    return Object.assign(new String(match), { escaped: true, sourceLength: match.length + 1 })
  }

// Q: rename to alpha09, alphadig, alpha_or_d?
alpha_d = [\p{Alpha}0-9]

not_mark_or_space = [^ `_*#:<\\\x10]

// NOTE regex starts to become faster than alternatives at ~ 3 characters
constrained_left_mark = [`_*#]

constrained_left_mark_in_code = '_' / '*' / '#'

constrained_left_mark_in_emphasis = '`' / '*' / '#'

constrained_left_mark_in_strong = '`' / '_' / '#'

constrained_left_mark_in_open = '`' / '_' / '*'

colon = ':'

space = ' '

any = .

offset = ''
  {
    return peg$currPos
  }
