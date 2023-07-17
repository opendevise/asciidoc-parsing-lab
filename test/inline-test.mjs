/* eslint-env mocha */
'use strict'

import { expect, makeTests, resolveDirname, scanTests, stringifyASG } from '#test-harness'
//import parse from 'asciidoc-parsing-lab'
import { parse as parseInline } from '#inline-parser'
import ospath from 'node:path'

const tests = await scanTests(ospath.join(resolveDirname(import.meta), 'tests/inline'))

describe('inline', () => {
  makeTests(tests, function ({ input, options, inputPath, expected, expectedWithoutLocations }) {
    //options = Object.assign({}, options, { parseInlines: true, preprocessLines: false })
    //const actual = parse(input, options).blocks?.[0]?.inlines
    if (options?.attributes) {
      options = Object.assign({}, options, {
        attributes: Object.entries(options.attributes).reduce((accum, [name, val]) => {
          accum[name] = { value: val, origin: 'external', locked: true }
          return accum
        }, {}),
      })
    }
    const actual = parseInline(input, options)
    if (expected == null) {
      // Q: can we write data to expected file automatically?
      // TODO only output expected if environment variable is set
      console.log(stringifyASG(actual))
      this.skip()
    } else {
      const msg = `actual output does not match expected output for ${inputPath}`
      expect(actual, msg).to.eql(!actual.length || 'location' in actual[0] ? expected : expectedWithoutLocations)
    }
  })

  it('empty input', () => {
    expect(parseInline('')).to.eql([])
  })
})
