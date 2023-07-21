/* eslint-env mocha */
'use strict'

const { expect } = require('chai')
const fsp = require('node:fs/promises')
const ospath = require('node:path')
const process = require('node:process')
const { fileURLToPath } = require('node:url')

function heredoc (strings, ...values) {
  const first = strings[0]
  if (first[0] !== '\n') {
    return values.length ? values.reduce((accum, value, idx) => accum + value + strings[idx + 1], first) : first
  }
  let string = values.length
    ? (strings = strings.slice()).push(strings.pop().trimEnd()) &&
      values.reduce((accum, _, idx) => accum + '\x1f' + strings[idx + 1], first.slice(1))
    : first.slice(1).trimEnd()
  const lines = string.split('\n')
  const indentSize = lines.reduce(
    (accum, line) =>
      accum && line ? (line[0] === ' ' ? Math.min(accum, line.length - line.trimStart().length) : 0) : accum,
    Infinity
  )
  if (indentSize) {
    string = lines.map((line) => (line && line[0] === ' ' ? line.slice(indentSize) : line)).join('\n')
    if (!values.length) return string
    strings = string.split('\x1f')
  } else if (!values.length) {
    return string
  }
  return values.reduce((accum, value, idx) => accum + value + strings[idx + 1], strings[0])
}

function resolveDirname ({ url }) {
  return ospath.dirname(fileURLToPath(url))
}

function makeTests (tests, testBlock) {
  for (const test of tests) {
    if (test.type === 'dir') {
      describe(test.name, () => makeTests(test.entries, testBlock))
    } else {
      ;(it[test.condition] || it)(test.name, function () {
        return testBlock.call(this, test.data)
      })
    }
  }
}

async function scanTests (dir = process.cwd(), base = process.cwd()) {
  const entries = []
  if (!ospath.isAbsolute(dir)) dir = ospath.resolve(dir)
  for await (const dirent of await fsp.opendir(dir)) {
    const name = dirent.name
    if (dirent.isDirectory()) {
      const childEntries = await scanTests(ospath.join(dir, name), base)
      if (childEntries.length) entries.push({ type: 'dir', name, entries: childEntries })
    } else if (name.endsWith('-input.adoc')) {
      const basename = name.slice(0, name.length - 11)
      const inputPath = ospath.join(dir, name)
      const outputPath = ospath.join(dir, basename + '-output.json')
      const configPath = ospath.join(dir, basename + '-config.json')
      entries.push(
        await Promise.all([
          fsp.readFile(inputPath, 'utf8'),
          fsp
            .readFile(outputPath)
            .then(
              (data) => [JSON.parse(data), JSON.parse(data, (key, val) => key === 'location' ? undefined : val)],
              () => []
            )
            .catch((ex) => {
              throw Object.assign(ex, { message: ex.message + ' in ' + ospath.relative(base, outputPath) })
            }),
          fsp.readFile(configPath).then(JSON.parse, () => ({})),
        ]).then(([input, [expected, expectedWithoutLocations], config]) => {
          if (config.trimTrailingWhitespace) {
            input = input.trimEnd()
          } else if (config.ensureTrailingNewline) {
            if (input[input.length - 1] !== '\n') input += '\n'
          } else if (input[input.length - 1] === '\n') {
            input = input.slice(0, input.length - 1)
          }
          return {
            type: 'test',
            name: config.name || basename.replace(/-/g, ' '),
            condition: config.only ? 'only' : config.skip ? 'skip' : undefined,
            data: {
              basename,
              inputPath: ospath.relative(base, inputPath),
              outputPath: ospath.relative(base, outputPath),
              input,
              options: config.options,
              expected,
              expectedWithoutLocations,
            },
          }
        })
      )
    }
  }
  return entries.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'test' ? -1 : 1
    return a.name.localeCompare(b.name)
  })
}

function populateASGDefaults (node) {
  if (node.type !== 'block') return node
  const metadata = node.metadata
  if (metadata) {
    metadata.attributes ??= {}
    metadata.options ??= []
    metadata.roles ??= []
  }
  const nodeName = node.name
  if (node.form === 'macro' || ['break', 'heading', 'attributes'].includes(nodeName)) return node
  if (['listing', 'literal', 'pass', 'stem', 'paragraph', 'verse'].includes(nodeName)) {
    node.inlines ??= []
  } else if (['list', 'dlist'].includes(nodeName)) {
    node.items.forEach(populateASGDefaults)
  } else {
    if (nodeName === 'document' && node.header) node.header.attributes ??= {}
    ;(node.blocks ??= []).forEach(populateASGDefaults)
  }
  return node
}

function stripASGDefaults (node) {
  if (node.type !== 'block') return node
  const metadata = node.metadata
  if (metadata) {
    if ('attributes' in metadata && !Object.keys(metadata.attributes).length) delete metadata.attributes
    if ('options' in metadata && !metadata.options.length) delete metadata.options
    if ('roles' in metadata && !metadata.roles.length) delete metadata.roles
  }
  const nodeName = node.name
  if (node.form === 'macro' || ['break', 'heading', 'attributes'].includes(nodeName)) return node
  if (['listing', 'literal', 'pass', 'stem', 'paragraph', 'verse'].includes(nodeName)) {
    if (!node.inlines.length) delete node.inlines
  } else if (['list', 'dlist'].includes(nodeName)) {
    node.items.forEach(stripASGDefaults)
  } else if (node.blocks?.length) {
    if (nodeName === 'document' && node.header && !Object.keys(node.header.attributes).length) {
      delete node.header.attributes
    }
    node.blocks.forEach(stripASGDefaults)
  } else {
    delete node.blocks
  }
  return node
}

function stringifyASG (asg) {
  const locations = []
  return JSON
    .stringify(stripASGDefaults(asg), (key, val) => key === 'location' ? locations.push(val) - 1 : val, 2)
    .replace(/("location": )(\d+)/g, (_, key, idx) => {
      return key + JSON.stringify(locations[Number(idx)], null, 2).replace(/\n */g, ' ').replace(/(\[) | (\])/g, '$1$2')
    })
}

module.exports = { expect, heredoc, resolveDirname, scanTests, makeTests, populateASGDefaults, stringifyASG }
