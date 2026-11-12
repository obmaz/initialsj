"""숭례문 영웅 오브젝트의 석축·홍예·중층 팔작지붕. 미터 단위 오프라인 형상."""
import math
from glb_shapes import ColoredMesh

STONE=(.57,.56,.49,1)
TILE=(.10,.21,.22,1)
WOOD=(.48,.12,.08,1)
GREEN=(.23,.35,.24,1)


def quad(mesh,a,b,c,d,color):
    mesh.tri(a,c,b,color)
    mesh.tri(a,d,c,color)


def roof(mesh,base,width,depth,rise,lower=False):
    columns,rows=8,5
    def vertex(x,u,side):
        reach=width*(.68+.32*u)
        # 처마 끝을 올리고 끝 네 모서리에 약간 더 큰 곡률을 준다.
        lift=1.4*max(0,(u-.65)/.35)**2
        y=base+rise*(1-u)**1.18+lift+abs(x)**5*u*1.0
        return (x*reach*.5,y,side*u*depth*.5)
    for side in [-1,1]:
        for row in range(rows):
            u0,u1=row/rows,(row+1)/rows
            for col in range(columns):
                x0,x1=-1+col*2/columns,-1+(col+1)*2/columns
                if lower and u1<=.4 and abs((x0+x1)*.5)<.7:
                    continue
                p=[vertex(x0,u0,side),vertex(x1,u0,side),vertex(x1,u1,side),vertex(x0,u1,side)]
                q=[(v[0],v[1]-.45,v[2]) for v in p]
                quad(mesh,*p,TILE)
                quad(mesh,q[3],q[2],q[1],q[0],TILE)
                # 내부 격자에는 옆면을 중복 생성하지 않는다.
                for edge in range(4):
                    perimeter=(edge==0 and row==0) or (edge==2 and row==rows-1) or (edge==3 and col==0) or (edge==1 and col==columns-1)
                    if perimeter:
                        j=(edge+1)%4
                        quad(mesh,p[edge],p[j],q[j],q[edge],TILE)
        # 기와 끝의 실제 단면과 처마 아래 서까래를 분리한다.
        for x in range(-int(width/2)+2,int(width/2),4):
            p=vertex(x/(width/2),1,side)
            mesh.box((p[0],p[1]-.4,p[2]-.2*side),(.35,.3,.9),GREEN)
        # 양 끝의 합각면을 두꺼운 지붕과 연결한다.
        for edge in [-1,1]:
            a=vertex(edge,0,side)
            b=vertex(edge,1,side)
            c=(edge*width*.5,base+1.5,0)
            mesh.tri(a,b,c,TILE)
            mesh.tri((a[0],a[1]-.4,a[2]),(c[0],c[1]-.4,c[2]),(b[0],b[1]-.4,b[2]),TILE)
    mesh.box((0,base+rise+.18,0),(width*.7,.65,.85),TILE)
    for end in [-1,1]:
        x=end*width*.35
        mesh.box((x,base+rise+.7,0),(1.0,.8,1.15),TILE)
        mesh.box((x+end*.45,base+rise+1.2,0),(.8,.8,.65),TILE)
        # 용마루 양끝의 치미를 큰 실루엣으로 남긴다.
        mesh.tri((x,base+rise+.8,-.4),(x+end*1.4,base+rise+2.0,0),(x+end*.6,base+rise+.8,.4),TILE)


def make_gate():
    mesh=ColoredMesh()
    for x in [-25,25]:
        mesh.box((x,.4,0),(14,.8,20),STONE)
        mesh.box((x,11,0),(14,22,17),STONE)
        # 석축 모서리와 상단의 돌출 띠.
        mesh.box((x,22.4,0),(14.5,1.0,18),STONE)
        for y in [3,9,15,20]:
            mesh.box((x,y,8.6),(14.0,.22,.26),STONE)
    mesh.box((0,22.0,0),(64,6,17),STONE)
    rx,ry,cy=18.0,13.2,5.0
    for i in range(24):
        a,b=math.pi*i/24,math.pi*(i+1)/24
        pa=(math.cos(a)*rx,cy+math.sin(a)*ry)
        pb=(math.cos(b)*rx,cy+math.sin(b)*ry)
        for z in [-8.5,8.5]:
            quad(mesh,(pa[0],pa[1],z),(pb[0],pb[1],z),(pb[0],19.2,z),(pa[0],19.2,z),STONE)
            outer_a=(math.cos(a)*(rx+1.3),cy+math.sin(a)*(ry+1.3),z+math.copysign(.12,z))
            outer_b=(math.cos(b)*(rx+1.3),cy+math.sin(b)*(ry+1.3),z+math.copysign(.12,z))
            quad(mesh,(pa[0],pa[1],z+math.copysign(.15,z)),(pb[0],pb[1],z+math.copysign(.15,z)),outer_b,outer_a,(.53,.52,.47,1))
        quad(mesh,(pa[0],pa[1],-8.5),(pa[0],pa[1],8.5),(pb[0],pb[1],8.5),(pb[0],pb[1],-8.5),STONE)
    # 난간·두꺼운 평방·기둥과 전용 단청 텍스처를 받을 인방·벽체.
    for floor,width,z,height in [(25.0,54.0,6.0,6.5),(34.0,42.0,4.8,6.0)]:
        mesh.box((0,floor,0),(width+1.5,.7,z*2+1.2),GREEN)
        for x in [-width*.43,-width*.28,-width*.14,0,width*.14,width*.28,width*.43]:
            for side in [-1,1]:
                mesh.box((x,floor+height*.5,side*z),(.9,height,.9),WOOD)
        for side in [-1,1]:
            mesh.box((0,floor+height-.35,side*z),(width,1.2,1.0),GREEN)
            mesh.box((0,floor+1,side*(z+.5)),(width,.38,.38),WOOD)
            # 큰 단청 면은 차에서 보이는 크기의6m 간격으로 구분한다.
            for x in [-18,-12,-6,0,6,12,18]:
                if abs(x)<width*.4:
                    mesh.box((x,floor+height*.53,side*(z-.12)),(5.5,height*.58,.24),WOOD)
    roof(mesh,30,64,24,6.0,True)
    roof(mesh,39.0,53,19,7.0)
    assert len(mesh.vertices)//9<3200, len(mesh.vertices)//9
    return mesh
