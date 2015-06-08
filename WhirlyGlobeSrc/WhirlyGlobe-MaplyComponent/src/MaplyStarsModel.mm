/*
 *  MaplyStarsModel.mm
 *  WhirlyGlobe-MaplyComponent
 *
 *  Created by Steve Gifford on 6/4/15.
 *  Copyright 2011-2015 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import <vector>
#import "MaplyStarsModel.h"

typedef struct
{
    float mag;
    MaplyCoordinate3d loc;
} SingleStar;

@implementation MaplyStarsModel
{
    std::vector<SingleStar> stars;
    MaplyParticleSystem *partSys;
    MaplyComponentObject *partSysObj;
    WhirlyGlobeViewController *__weak viewC;
    MaplyThreadMode addedMode;
}

- (id)initWithFileName:(NSString *)fileName
{
    self = [super init];
    
    FILE *fp = fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding],"r");
    if (!fp)
        return nil;

    // Mangitude x y z
    char line[1024];
    while (fgets(line, 1023, fp))
    {
        stars.resize(stars.size()+1);
        SingleStar &star = stars.back();
        sscanf(line, "%f %f %f %f", &star.mag, &star.loc.x, &star.loc.y, &star.loc.z);
    }
    
    return self;
}

static const char *vertexShaderTriPoint =
"uniform mat4  u_mvpMatrix;"
"uniform float u_radius;"
""
"attribute vec3 a_position;"
"attribute float a_size;"
""
"varying vec4 v_color;"
""
"void main()"
"{"
"   v_color = vec4(1.0,0.0,1.0,1.0);"
"   gl_PointSize = a_size;"
"   gl_Position = u_mvpMatrix * vec4(a_position * u_radius,1.0);"
"}"
;

static const char *fragmentShaderTriPoint =
"precision lowp float;"
""
"varying vec4      v_color;"
""
"void main()"
"{"
"  gl_FragColor = v_color;"
"}"
;

typedef struct
{
    float x,y,z;
} SimpleVec3;

- (void)addToViewC:(WhirlyGlobeViewController *)inViewC desc:(NSDictionary *)desc mode:(MaplyThreadMode)mode
{
    viewC = inViewC;
    addedMode = mode;

    // Really simple shader
    MaplyShader *shader = [[MaplyShader alloc] initWithName:@"Star Shader" vertex:[NSString stringWithFormat:@"%s",vertexShaderTriPoint] fragment:[NSString stringWithFormat:@"%s",fragmentShaderTriPoint] viewC:viewC];
    [viewC addShaderProgram:shader sceneName:@"Star Shader"];
    [shader setUniformFloatNamed:@"u_radius" val:1.5];

    // Set up a simple particle system (that doesn't move)
    partSys = [[MaplyParticleSystem alloc] initWithName:@"Stars"];
    partSys.type = MaplyParticleSystemTypePoint;
    partSys.lifetime = 1e20;
    partSys.totalParticles = stars.size();
    partSys.batchSize = stars.size();
    partSys.shader = shader.name;
    [partSys addAttribute:@"a_position" type:MaplyShaderAttrTypeFloat3];
    [partSys addAttribute:@"a_size" type:MaplyShaderAttrTypeFloat];
    partSysObj = [viewC addParticleSystem:partSys desc:desc mode:mode];
    
    // Data arrays for particles
    // We'll clear them out in case we don't fill them out completely
    SimpleVec3 pos[stars.size()];
    memset(pos, 0, stars.size()*sizeof(SimpleVec3));
    float mag[stars.size()];
    memset(mag, 0, stars.size()*sizeof(float));

    SimpleVec3 *posPtr = pos;
    float *magPtr = mag;
    for (unsigned int ii=0;ii<stars.size();ii++)
    {
        SingleStar *star = &stars[ii];
        
        posPtr->x = star->loc.x;
        posPtr->y = star->loc.y;
        posPtr->z = star->loc.z;
        *magPtr = 6.0;
        
        posPtr++;   magPtr++;
    }

    // Set up the particle batch
    MaplyParticleBatch *batch = [[MaplyParticleBatch alloc] initWithParticleSystem:partSys];
    batch.time = CFAbsoluteTimeGetCurrent();
    NSData *posData = [[NSData alloc] initWithBytesNoCopy:pos length:stars.size()*sizeof(SimpleVec3) freeWhenDone:false];
    [batch addAttribute:@"a_position" values:posData];
    NSData *sizeData = [[NSData alloc] initWithBytesNoCopy:mag length:stars.size()*sizeof(float) freeWhenDone:false];
    [batch addAttribute:@"a_size" values:sizeData];
    [viewC addParticleBatch:batch mode:mode];
}

- (void)removeFromViewC
{
    if (partSysObj)
        [viewC removeObjects:@[partSys] mode:addedMode];
}

@end