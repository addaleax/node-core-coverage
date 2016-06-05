#!/usr/bin/env python
# -*- coding: utf-8 -*-

with open('out/index.csv') as index:
  index_csv = filter(lambda line: line, index.read().split('\n'))

with open('out/index.html', 'w') as out:
  out.write(
'''
<!DOCTYPE html>
<html>
  <head>
    <title>Node.js core test coverage</title>
    <link rel="stylesheet" type="text/css" href="style.css" />
  </head>
  <body><div id="wrap">
    <h1>Node.js core test coverage</h1>
    <table>
      <tr>
        <th>Date</th>
        <th>HEAD</th>
        <th>JS Coverage</th>
        <th>C++ Coverage</th>
      </tr>
''')
  for line in reversed(index_csv):
    jscov, cxxcov, date, sha = line.split(',')
    out.write('''<tr>
      <td>{0}</td>
      <td><a href="https://github.com/nodejs/node/commit/{1}">{1}</a></td>
      <td><a href="coverage-{1}/index.html">{2:05.2f}&nbsp;%</a></td>
      <td><a href="coverage-{1}/cxxcoverage.html">{3:05.2f}&nbsp;%</a></td>
    </tr>'''.format(date, sha, float(jscov), float(cxxcov)))

  out.write('''</table>
  </div></body>
</html>''')
