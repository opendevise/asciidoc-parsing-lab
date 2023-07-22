'use strict'

const HTML_TAG_NAME_BY_SPAN_VARIANT = { code: 'code', emphasis: 'em', mark: 'mark', strong: 'strong' }

function convert (node, documentAttributes) {
  let output = ''
  let tagName
  switch (node.name) {
    case 'document': {
      documentAttributes = Object.assign({}, node.attributes)
      let convertedTitle
      const header = node.header
      if (header) {
        if (header.attributes) {
          for (const [name, { value }] of Object.entries(header.attributes)) {
            if (!documentAttributes[name]?.locked) documentAttributes[name] = { value, origin: 'header' }
          }
        }
        if (header.title) convertedTitle = convertInlines(header.title)
      }
      const standalone = documentAttributes.embedded == null
      if (standalone) {
        output += '<!DOCTYPE html>\n<html>\n<head>\n'
        // FIXME downconvert contents of title tag to plain text
        if (convertedTitle) output += `<title>${convertedTitle}</title>\n`
        output += `<style>\n${css()}\n</style>\n`
        output += '</head>\n<body>\n'
      }
      output += '<article>\n'
      if (convertedTitle) output += `<header>\n<h1>${convertedTitle}</h1>\n</header>\n`
      if (node.blocks.length) {
        for (const child of node.blocks) output += convert(child, documentAttributes)
      }
      output += '</article>'
      if (standalone) output += '\n</body>\n</html>'
      break
    }
    case 'paragraph':
      if (node.metadata?.options.includes('hardbreaks')) {
        output += `<p${commonAttributes(node.metadata)}>${convertInlines(node.inlines).replace(/\n/g, '<br>')}</p>\n`
      } else {
        output += `<p${commonAttributes(node.metadata)}>${convertInlines(node.inlines)}</p>\n`
      }
      break
    case 'section':
      output += `<section${commonAttributes(node.metadata)}>\n`
      output += `<${(tagName = `h${node.level + 1}`)}>${convertInlines(node.title)}</${tagName}>\n`
      if (node.blocks.length) {
        for (const child of node.blocks) output += convert(child, documentAttributes)
      }
      output += '</section>\n'
      break
    case 'preamble':
      // Q: should preamble have an enclosure?
      for (const child of node.blocks) output += convert(child, documentAttributes)
      break
    case 'heading':
      output += `<${(tagName = `h${node.level + 1}`)}${commonAttributes(node.metadata, 'discrete')}>${convertInlines(node.title)}</${tagName}>\n`
      break
    case 'literal':
    case 'listing':
      if (node.metadata?.attributes.style === 'source') {
        const language = node.metadata.attributes.language
        output += `<pre${commonAttributes(node.metadata)}><code${language ? ` data-lang="${language}"` : ''}>${convertInlines(node.inlines)}</code></pre>\n`
      } else {
        output += `<pre${commonAttributes(node.metadata)}>${convertInlines(node.inlines)}</pre>\n`
      }
      break
    case 'list': {
      let listAttrs = ''
      if (node.variant === 'ordered') {
        tagName = 'ol'
        const start = node.metadata?.attributes.start
        if (start) listAttrs = ` start="${start}"`
      } else {
        tagName = 'ul'
      }
      output += `<${tagName}${commonAttributes(node.metadata)}${listAttrs}>\n`
      for (const item of node.items) {
        output += '<li>\n'
        output += `<span class="principal">${convertInlines(item.principal)}</span>\n`
        if (item.blocks.length) {
          for (const child of item.blocks) output += convert(child, documentAttributes)
        }
        output += '</li>\n'
      }
      output += `</${tagName}>\n`
      break
    }
    case 'dlist':
      output += `<dl${commonAttributes(node.metadata)}>\n`
      for (const item of node.items) {
        for (const term of item.terms) output += `<dt>${convertInlines(term)}</dt>\n`
        if (item.principal || item.blocks.length) {
          output += '<dd>\n'
          if (item.principal) output += `<span class="principal">${convertInlines(item.principal)}</span>\n`
          if (item.blocks.length) {
            for (const child of item.blocks) output += convert(child, documentAttributes)
          }
          output += '</dd>\n'
        }
      }
      output += '</dl>\n'
      break
    case 'admonition':
      output += `<div${commonAttributes(node.metadata, 'admonition')} data-severity="${node.variant}">\n`
      for (const child of node.blocks) output += convert(child, documentAttributes)
      output += '</div>\n'
      break
    case 'sidebar':
      output += `<aside${commonAttributes(node.metadata)}>\n`
      for (const child of node.blocks) output += convert(child, documentAttributes)
      output += '</aside>\n'
      break
    case 'example':
      output += `<div${commonAttributes(node.metadata, 'example')}>\n`
      for (const child of node.blocks) output += convert(child, documentAttributes)
      output += '</div>\n'
      break
    case 'image':
      output += `<figure${commonAttributes(node.metadata)}>\n`
      output += `<img src="${node.target}" alt="${node.metadata?.attributes.alt}">\n`
      output += '</figure>\n'
      break
    case 'attributes':
      for (const [name, { value }] of Object.entries(node.attributes)) {
        if (!documentAttributes[name]?.locked) documentAttributes[name] = { value, origin: 'body' }
      }
      break
    default:
      console.warn(`${node.name} not converted`)
  }
  return output
}

function css () {
  return `
body {
  color: #222222;
  font-family: sans-serif;
  margin: 0;
}
article {
  display: flow-root;
  margin: 2em auto;
  width: 80vw;
}
article > header h1 {
  margin-top: 0;
  font-size: 2em;
}
article > :first-child:not(header) {
  margin-top: 0;
}
a {
  color: #0000cc;
}
p,
li > .principal:first-child,
dd > .principal:first-child {
  line-height: 1.6;
}
dt {
  font-weight: bold;
}
dd {
  margin-left: 1.5em;
}
code,
pre {
  color: #aa0000;
  font-size: 1.25em;
}
pre {
  line-height: 1.25;
}
pre code {
  font-size: inherit;
}
.admonition,
.example {
  border: 1px solid currentColor;
  margin-block: 1em 0;
  padding: 0 1em;
}
.admonition::before {
  content: attr(data-severity);
  display: block;
  font-weight: bold;
  text-transform: uppercase;
  margin-top: 1em;
}
figure {
  margin-left: 0;
}
img {
  display: inline-block;
  max-width: 100%;
  vertical-align: middle;
}
`.trim()
}

function convertInlines (nodes) {
  return nodes.reduce((buffer, node) => {
    let tagName
    switch (node.name) {
      case 'text':
        //buffer.push(node.value)
        // FIXME grammar should be giving us a hard break inline
        buffer.push(node.value.replace(/ \+(?=\n)/g, '<br>'))
        break
      case 'ref':
        buffer.push(`<a href="${node.target}">${convertInlines(node.inlines)}</a>`)
        break
      case 'span':
        buffer.push(`<${(tagName = HTML_TAG_NAME_BY_SPAN_VARIANT[node.variant])}>${convertInlines(node.inlines)}</${tagName}>`)
        break
      default:
        console.warn(`${node.name} not converted`)
    }
    return buffer
  }, []).join('')
}

function commonAttributes (metadata, primaryRole) {
  if (!metadata) return primaryRole ? ` class="${primaryRole}"` : ''
  const { attributes, id, roles: secondaryRoles = [] } = metadata
  const roles = primaryRole ? [primaryRole] : []
  for (const role of secondaryRoles) roles.push(role)
  const dataAttributes = Object.keys(attributes).filter((n) => n.startsWith('data-'))
  const data = dataAttributes.length ? dataAttributes.map((n) => ` ${n}="${attributes[n]}"`).join('') : ''
  if (id) {
    return roles.length ? ` id="${id}" class="${roles.join(' ')}"` : ` id="${id}"${data}`
  } else if (roles.length) {
    return ` class="${roles.join(' ')}"${data}`
  }
  return data
}

module.exports = convert
