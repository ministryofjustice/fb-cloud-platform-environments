#!/usr/bin/env node

const nunjucks = require('nunjucks')
const path = require('path')
const yaml = require('yaml')
const fs = require('fs')
const args = require('yargs').argv

const {chart, env} = args

const resourcesDir = path.resolve(__dirname, '..', chart, 'resources')
const valuesFile = path.resolve(resourcesDir, '..', 'values.yaml')
const envValuesFile = path.resolve(resourcesDir, '..', 'values', `${env}-values.yaml`)

const values = yaml.parse(fs.readFileSync(valuesFile, 'utf8'))
const envValues = yaml.parse(fs.readFileSync(envValuesFile, 'utf8'))

const nunjucksArgs = Object.assign(values, envValues)

nunjucks.configure(resourcesDir, {autoescape: false})
const output = nunjucks.render('variables.tf', nunjucksArgs)

process.stdout.write(output)
