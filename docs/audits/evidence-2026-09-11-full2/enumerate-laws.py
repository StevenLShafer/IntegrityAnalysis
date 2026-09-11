"""Independent exact rational fixed-margin enumeration, Codex, 2026-09-11."""
from fractions import Fraction
from math import factorial, prod
from pathlib import Path
import csv
import json

out = Path(__file__).resolve().parent

def vectors(total, caps):
    if len(caps) == 1:
        if total <= caps[0]:
            yield [total]
        return
    for x in range(min(total, caps[0]) + 1):
        for tail in vectors(total-x, caps[1:]):
            yield [x] + tail

def tables(rows, cols):
    if len(rows) == 1:
        if sum(cols) == rows[0]:
            yield [cols]
        return
    for row in vectors(rows[0], cols):
        for tail in tables(rows[1:], [c-x for c, x in zip(cols, row)]):
            yield [row] + tail

specs = [('three_by_two', [2,2,6], [3,7], 9),
         ('three_by_three', [2,3,4], [2,3,4], 3),
         ('three_equal_arms', [3,3,3], [2,3,4], 3),
         ('three_larger', [3,4,5], [2,4,6], 3)]
data = {}
for name, rows, cols, J in specs:
    N = sum(rows)
    common = Fraction(prod(factorial(x) for x in rows+cols), factorial(N))
    law, example = {}, {}
    for tab in tables(rows, cols):
        stat = sum(Fraction((tab[i][j]*N-rows[i]*cols[j])**2, N*rows[i]*cols[j])
                   for i in range(len(rows)) for j in range(len(cols)))
        mass = common / prod(factorial(x) for row in tab for x in row)
        law[stat] = law.get(stat, Fraction()) + mass
        example.setdefault(stat, tab)
    assert sum(law.values()) == 1
    states = sorted(law)
    q0, q1 = law[states[0]], law[states[1]]
    expected = q0**J + Fraction(J,2)*q1*q0**(J-1)
    data[name] = dict(rows=rows, cols=cols, J=J, minimum=example[states[0]],
                      next=example[states[1]], q0=float(q0), q1=float(q1),
                      exact_trial=float(expected), exact_trial_fraction=str(expected),
                      states=[dict(statistic=float(s), rational=str(s), probability=float(law[s])) for s in states])
    with (out / ('exact-multilevel-'+name+'.csv')).open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['statistic','rational_statistic','probability','rational_probability'])
        w.writerows((float(s),str(s),float(law[s]),str(law[s])) for s in states)
    print(name, 'states', len(states), 'q0',float(q0),'q1',float(q1),'J',J,'exact',float(expected))
(out/'multilevel-laws.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
