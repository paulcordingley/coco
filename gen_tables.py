import math

VX = [-1, 1, 1,-1,-1, 1, 1,-1]
VY = [-1,-1, 1, 1,-1,-1, 1, 1]
VZ = [-1,-1,-1,-1, 1, 1, 1, 1]
EDGES = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]

NF = 36
D = 3.5
S = 90
T = 2*math.pi/NF

xt = []
yt = []
for f in range(NF):
    A = f*T
    B = 2*A
    ca, sa = math.cos(A), math.sin(A)
    cb, sb = math.cos(B), math.sin(B)
    for i in range(8):
        x1 = VX[i]*ca + VZ[i]*sa
        z1 = VZ[i]*ca - VX[i]*sa
        y2 = VY[i]*cb - z1*sb
        z2 = VY[i]*sb + z1*cb
        p = S/(z2+D)
        x = int(128 + x1*p + 0.5)
        y = int(96 + y2*p + 0.5)
        assert 0 <= x <= 255, (f,i,x)
        assert 0 <= y <= 255, (f,i,y)
        xt.append(x)
        yt.append(y)

def fcb_lines(label, data, width=16):
    lines = [f"{label}"]
    for i in range(0, len(data), width):
        chunk = data[i:i+width]
        lines.append("        FCB     " + ",".join(str(v) for v in chunk))
    return "\n".join(lines)

with open("tables.inc", "w") as f:
    f.write(fcb_lines("VXTAB", xt) + "\n")
    f.write(fcb_lines("VYTAB", yt) + "\n")
    edge_bytes = []
    for a,b in EDGES:
        edge_bytes += [a,b]
    f.write(fcb_lines("EDGES", edge_bytes) + "\n")

print("frame0 vertex0..2:", list(zip(xt[:3], yt[:3])))
print("total x entries:", len(xt), "total y entries:", len(yt))
