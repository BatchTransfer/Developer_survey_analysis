"""Build analysis_pipeline_v4.drawio (fig:analysis-pipeline) from analysis_pipeline_v3.drawio, so it keeps V3's size, styles and icons,
with the new dispatcher-based classifier and its numbers; the classifier logic (former classifier_logic figure) is in the Classification box.
Numbers: 79 ERC specifications; 3,808,540 contracts; 2,369,723 implementing (>70%); 12,673 flagged; 100 sampled (seed 2046), 100 TP, 0 FP,
Wilson 95% CI 96.3-100%. Export:
  python make_pipeline_figures.py && /Applications/draw.io.app/Contents/MacOS/draw.io -x -f pdf --crop -o analysis_pipeline_v4.pdf analysis_pipeline_v4.drawio"""
import xml.etree.ElementTree as ET
T = '<b style=""><font style="font-size: 14px;">{}</font></b><br><font style="font-size: 11px;" color="#333333">{}</font>'
VAL = {'c3': T.format('ERC specifications', '79 specs, mandatory functions'),
       'c5': T.format('Deployed contracts', '3.8M contracts, 4 chains,<br>2018 to Dec 2024'),
       'c7': T.format('Dispatcher reading', 'exposed functions only:<br>PUSH4&#8211;EQ selectors'),
       'c9': T.format('Classification', '&gt;70%: implements (2.37M)<br>100%: compliant<br>below 100%: flagged (12,673)'),
       'c11': T.format('Random sample', '100 of the 12,673<br>flagged contracts'),
       'c13': T.format('Manual labels', 'Violation or<br>Not a Violation'),
       'c15': T.format('Precision 100%', '100 TP, 0 FP<br>95% CI 96.3&#8211;100%')}
X = {'c11': 452, 'c12': 460, 'c15': 72, 'c16': 80}          # validation row runs right to left: sample sits under Classification
t = ET.parse('analysis_pipeline_v3.drawio'); root = t.getroot(); parent = next(root.iter('root'))
for c in list(parent):
    i = c.get('id')
    if i in VAL: c.set('value', VAL[i].replace('&#8211;', '–'))
    if i in X: c.find('mxGeometry').set('x', str(X[i]))
    if i == 'c20': c.set('source', 'c9'); c.set('target', 'c11')   # sample is drawn from the flagged contracts
    if i == 'c23': parent.remove(c)                                 # precision is measured on the sample only
    if c.get('edge'):
        g = c.find('mxGeometry')
        for a in list(g): g.remove(a)                               # let draw.io route the edges
t.find('diagram').set('name', 'Analysis pipeline v4'); t.write('analysis_pipeline_v4.drawio', encoding='unicode')
print('wrote analysis_pipeline_v4.drawio')
