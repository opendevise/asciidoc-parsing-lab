{{
const fs = require('node:fs')
const ospath = require('node:path')
const { splitLines, unshiftOntoCopy } = require('#util')
}}
{
if (!input) return { input }
const documentAttributes = Object.assign({}, options.attributes)
const locations = {} // maps line numbers to location objects
}
document = lf* body .*
  {
    const lineOffset = locations.lineOffset
    if (lineOffset == null) return { input }
    delete locations.lineOffset
    if (!input) return { input, locations: {} }
    const end = location().end
    let lastLine = end.offset && end.line
    for (let n = lastLine; n > 0; n--) {
      if (n in locations) break
      locations[n] = { line: n + lineOffset, col: 1, lineOffset }
    }
    let extra = lastLine + 1
    while (extra in locations) delete locations[extra++]
    // Q: is it necessary to track lineOffset on entries in the first place?
    //for (const l in locations) delete locations[l].lineOffset
    return { input, locations }
  }

body = block*

block = (pp (lf / attribute_entry))* @(heading / example / listing / list / paragraph)

heading = '='+ space space* line

example = '====\n' contents:paragraph pp '====' eol
  {
    return { name: 'example', contents, location: location() }
  }

listing = '----\n' contents:$(pp !('----' eol) line / lf)* pp '----' eol
  {
    return { name: 'listing', contents, location: location() }
  }

paragraph = contents:line|1.., pp !('====' eol / list_marker)|
  {
    return { name: 'paragraph', contents, location: location() }
  }

list = items:list_item|1.., pp|
  {
    return { name: 'list', items, location: location() }
  }

list_marker = ('*' '*'* / '.' '.'* / '-' / [0-9]+ '.') space space* !eol

list_item = list_marker principal:$(line (pp !('+\n' / list_marker / '====' eol) line)*) blocks:attached_block*
  {
    return { name: 'listItem', principal, blocks, location: location() }
  }

attached_block = pp '+\n' @(example / paragraph)

attribute_entry = ':' negatedPrefix:'!'? name:attribute_name negatedSuffix:'!'? ':' value:attribute_value? eol
  {
    negatedPrefix || negatedSuffix ? delete documentAttributes[name] : (documentAttributes[name] = value || '')
  }

conditional_lines = lines:(!('endif::[]' eol) @(pp_conditional_pair / line / lf))*
  {
    return lines.flat()
  }

pp_conditional_pair = opening:$('if' 'n'? 'def::' attribute_name '[]\n') contents:conditional_lines closing:$('endif::[]' eol)?
  {
    if (closing) contents.push(closing)
    return unshiftOntoCopy(contents, opening)
  }

//pp = (pp_directive* &{ return false })?
pp = (pp_directive* !. &.)?
// Q: is there a cleaner way to fail pp_directive to restore currPos, but still keep checking??
//pp = ((modified:(&{ return true } { return {} }) (pp_directive &{ return !(modified.true = true) } / &{ return modified.true }))* . !.)?

pp_directive = &('if' / 'inc') @(pp_conditional_short / pp_conditional / pp_include)

//pp_include = 'include::' target:$((!'\n' !'[' !' ' .) ((!'\n' !'[' !' ' .) / space !'[')*) '[]' eol:eol
pp_include = 'include::' !space target:$((!'\n' !'[' !' ' .) / space !'[')+ '[]' eol:eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const lineOffset = (locations.lineOffset ??= 0)
    if (!locations[startLine - 1]) {
      for (let n = startLine - 1; n > 0; n--) {
        if (n in locations) break
        locations[n] = { line: n + lineOffset, col: 1, lineOffset }
      }
    }
    // FIXME include file should be resolved relative to nested include, when applicable
    const contents = splitLines(fs.readFileSync(ospath.join(documentAttributes.docdir || '', target), 'utf8'))
    const contentsLastLineIdx = contents.length - 1
    let numAdded = 0
    if (~contentsLastLineIdx) {
      numAdded = contentsLastLineIdx + 1
      if (eol) {
        const contentsLastLine = contents[contentsLastLineIdx]
        if (contentsLastLine) {
          contents[contentsLastLineIdx] += '\n'
          contents.push('')
        } else {
          numAdded--
        }
      }
    }
    if (endLine in locations) {
      const shiftedLocations = []
      let n = endLine
      while (n in locations) shiftedLocations[n + numAdded] = locations[n++]
      Object.assign(locations, shiftedLocations)
    }
    const file = [...locations[startLine]?.file || [], target]
    for (let l = 0, len = numAdded; l < len; l++) {
      locations[l + startLine] = { line: l + 1, col: 1, lineOffset: 0, file }
    }
    locations.lineOffset -= (numAdded - 1)
    input = input.slice(0, (peg$currPos = startOffset)) + contents.join('') + input.slice(endOffset)
    // NOTE might be able to avoid this if we don't rely on location()
    peg$posDetailsCache = [{ line: 1, col: 1 }]
    return true
  }

pp_conditional_short = negated:('if' @'n'? 'def') '::' attributeName:attribute_name '[' contentsOffset:offset contents:$((!'\n' '!]' .)+ &(']' eol) / ((!'\n' !']' .) / ']' !eol)+) ']' eol:eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const lineOffset = (locations.lineOffset ??= 0)
    for (let n = startLine; n > 0; n--) {
      if (n in locations) break
      locations[n] = { line: n + lineOffset, col: 1, lineOffset }
    }
    const drop = negated ? (attributeName in documentAttributes) : !(attributeName in documentAttributes)
    if (drop) {
      if (eol) {
        let n = endLine
        if (!locations[n]) locations[n] = { line: n + lineOffset, col: 1, lineOffset }
        while (n in locations) {
          locations[n].lineOffset++
          locations[n - 1] = locations[n]
          delete locations[n++]
        }
        locations.lineOffset++
      } else {
        delete locations[startLine]
      }
    } else {
      locations[startLine].col = contentsOffset - startOffset + 1
    }
    input = input.slice(0, (peg$currPos = startOffset)) + (drop ? '' : contents + (eol || '')) + input.slice(endOffset)
    peg$posDetailsCache = [{ line: 1, col: 1 }]
    return true
  }

// TODO always succeed even if endif::[] is missing
// Q could the positive case only process the opening directive and process the closing directive separately? the negative case would still have to consume lines, so this might require the use of a semantic predicate
pp_conditional = negated:('if' @'n'? 'def') '::' attributeName:attribute_name '[]\n' contents:conditional_lines 'endif::[]' eol:eol
  {
    const { start: { offset: startOffset, line: startLine }, end: { offset: endOffset, line: endLine } } = location()
    const newEndLine = endLine - 2
    const lineOffset = (locations.lineOffset ??= 0)
    // Q: better to do this in the document action?
    if (!locations[startLine - 1]) {
      for (let n = startLine - 1; n > 0; n--) {
        if (n in locations) break
        locations[n] = { line: n + lineOffset, col: 1, lineOffset }
      }
    }
    const drop = negated ? (attributeName in documentAttributes) : !(attributeName in documentAttributes)
    if (drop) {
      const numDropped = contents.length + 2
      let l = endLine
      if (!locations[l]) locations[l] = { line: l + lineOffset, col: 1, lineOffset }
      while (l in locations) locations[l++].lineOffset += numDropped
      for (let n = startLine; n < endLine; n++) delete locations[n]
      let n = endLine
      while (n in locations) {
        locations[n - numDropped] = locations[n]
        delete locations[n++]
      }
      locations.lineOffset = locations[n - 1 - numDropped].lineOffset
    } else {
      if (!locations[startLine]) {
        for (let l = startLine; l < endLine; l++) locations[l] = { line: l + lineOffset, col: 1, lineOffset }
      }
      let l = startLine
      const currentInclude = locations[startLine].file
      let closingLine = eol ? endLine - 1 : endLine
      let newLineOffset = lineOffset + 2
      while (l in locations) {
        // FIXME only move lineOffset if in same file
        if (l > startLine && locations[l].file === currentInclude) {
          l > closingLine ? (newLineOffset = locations[l].lineOffset += 2) : locations[l].lineOffset++
        }
        if (l !== startLine && l !== closingLine) locations[l - (l > closingLine ? 2 : 1)] = locations[l]
        delete locations[l++]
      }
      // NOTE if included lines are reduced then root lineOffset increases
      currentInclude ? (locations.lineOffset += 2) : (locations.lineOffset = newLineOffset)
    }
    input = input.slice(0, (peg$currPos = startOffset)) + (drop ? '' : contents.join('')) + input.slice(endOffset)
    peg$posDetailsCache = [{ line: 1, col: 1 }]
    return true
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = !'-' @$[a-zA-Z0-9_-]+

attribute_value = space @$(!'\n' .)+

offset = ''
  {
    return peg$currPos
  }

line = $((!'\n' .)+ eol)

space = ' '

lf = '\n'

eof = !.

eol = '\n' / !.
