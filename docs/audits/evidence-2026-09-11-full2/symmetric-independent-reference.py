"""Independent NumPy implementation of the three selected nulls, Codex 2026-09-11.

No engine functions or engine draws are used. Integer differences classify
outcomes. Exact multinomial event probabilities then combine the row law.
Confidence bounds enclose a simultaneous Hoeffding box on its three
relevant masses; these are reference uncertainty, not application intervals.
"""
import csv, itertools, json, math, os
from pathlib import Path
import numpy as np
from statistics import NormalDist

out = Path(os.environ['INTEGRITY_AUDIT_OUTPUT'])
B, seed, chunk = 2_000_000, 9173, 10_000
records = []
for kind in ('continuous', 'direct', 'median'):
    rng = np.random.default_rng(seed)
    counts = np.zeros(3, dtype=np.int64)
    for first in range(0, B, chunk):
        b = min(chunk, B-first)
        if kind in ('continuous', 'direct'):
            n, sd = (30, 6.) if kind == 'continuous' else (100, 10.)
            s = rng.uniform(sd-.05, sd+.05, (b, 2))
            sigma = np.sqrt(np.sum((n-1)*s*s, axis=1)/rng.chisquare(2*n-2, b))
            loc = rng.normal(0, sigma/math.sqrt(n))
            means = []
            for arm in range(2):
                if kind == 'continuous':
                    x = rng.normal(size=(b,n))*sigma[:,None]+loc[:,None]
                    means.append(np.rint(np.mean(np.rint(x), axis=1)))
                else:
                    x = rng.normal(loc, np.sqrt((sigma*sigma+1/12)/n))
                    means.append(np.rint(np.rint(x*n)/n))
        else:
            n = 9
            q1 = np.mean(rng.uniform(-1.05, -.95, (b,2)), axis=1)
            q3 = np.mean(rng.uniform(.95, 1.05, (b,2)), axis=1)
            aq = np.maximum((q3-q1)/(2*math.log(3)), .001/(2*math.log(3)))
            cq = np.clip(2*(q1+q3)/math.log(3), -1.66*aq, 1.66*aq)
            def draw(loc, scale, skew):
                u = rng.uniform(1e-12, 1-1e-12, (b,n))
                return loc[:,None]+(scale[:,None]+skew[:,None]*(u-.5))*np.log(u/(1-u))
            bq1 = np.zeros(b); bq3 = np.zeros(b)
            for arm in range(2):
                x = np.sort(np.rint(draw(np.zeros(b), aq, cq)), axis=1)
                # At n=9, type-7 quartiles are order statistics 3 and 7.
                bq1 += .5*np.round(x[:,2], 1)
                bq3 += .5*np.round(x[:,6], 1)
            boot = np.maximum((bq3-bq1)/(2*math.log(3)), .1/(2*math.log(3)))
            ar = aq*aq/boot
            cr = np.clip(cq, -1.66*ar, 1.66*ar)
            loc = rng.normal(0, 2*ar/math.sqrt(n))
            means = [np.median(np.rint(draw(loc,ar,cr)), axis=1) for arm in range(2)]
        diff = np.abs(means[0]-means[1])
        counts += [np.sum(diff==k) for k in (0,1,2)]
        if (first+chunk) % 100_000 == 0:
            (out/f'symmetric-reference-{kind}-checkpoint.json').write_text(json.dumps(
                dict(kind=kind,completed=first+b,seed=seed,counts=counts.tolist())))
    p = counts/B
    # P(any of three absolute mass errors > epsilon) <= 6 exp(-2 B eps^2).
    epsilon = math.sqrt(math.log(6/.05)/(2*B))
    lo = np.maximum(0,p-epsilon)
    hi = np.minimum(1,p+epsilon)
    def cost_ratio(x):
        z = -np.array([NormalDist().inv_cdf(y) for y in
            (x[0]/2, x[0]+x[1]/2, x[0]+x[1]+x[2]/2)])
        return (z[0]-z[2])/(z[0]-z[1])
    ratios = [cost_ratio(x) for x in itertools.product(*zip(lo,hi))]
    t = math.floor(cost_ratio(p))
    assert all(math.floor(x)==t for x in ratios), 'Ordering uncertain in reference box'
    qlo = (lo[0]/2,lo[0]+lo[1]/2,lo[0]+lo[1]+lo[2]/2)
    qhi = (hi[0]/2,hi[0]+hi[1]/2,hi[0]+hi[1]+hi[2]/2)
    zlo = [-NormalDist().inv_cdf(q) for q in qhi]
    zhi = [-NormalDist().inv_cdf(q) for q in qlo]
    ratio_lower = (zlo[0]-zhi[2])/(zhi[0]-zlo[1])
    ratio_upper = (zhi[0]-zlo[2])/(zlo[0]-zhi[1])
    assert t < ratio_lower <= ratio_upper < t+1
    def combine(x,J):
        return sum(math.comb(J,k)*x[1]**k*x[0]**(J-k) for k in range(min(J,t)+1)) + .5*J*x[2]*x[0]**(J-1)
    for J in (5,6,7,8,9,14):
        records.append(dict(kind=kind,J=J,B=B,seed=seed,p0=p[0],p1=p[1],p2=p[2],
            cost_ratio=cost_ratio(p),max_unit_differences=t,reference_p=combine(p,J),
            simultaneous95_lower=combine(lo,J),simultaneous95_upper=combine(hi,J),
            ratio_bound_lower=ratio_lower,ratio_bound_upper=ratio_upper))
    with (out/'symmetric-independent-reference.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=records[0].keys());w.writeheader();w.writerows(records)
    print(kind,counts.tolist(),'ratio',cost_ratio(p),'complete',flush=True)
(out/'symmetric-independent-complete.txt').write_text('Complete; independent PCG64 draws and integer events.\n')
