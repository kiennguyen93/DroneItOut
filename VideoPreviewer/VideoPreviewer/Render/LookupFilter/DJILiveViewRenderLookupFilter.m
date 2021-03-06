//
//  DJILiveViewRenderLookupFilter.m
//  DJIWidget
//
//  Created by ai.chuyue on 2016/10/26.
//  Copyright © 2016年 Jerome.zhang. All rights reserved.
//

#import "DJILiveViewRenderCommon.h"
#import "DJILiveViewRenderLookupFilter.h"

NSString *const kDJIGPUImageLookupFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 uniform lowp float intensity;
 
 void main()
 {
     highp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     highp float blueColor = textureColor.b * 63.0;
     
     highp vec2 quad1;
     quad1.y = floor(floor(blueColor) / 8.0);
     quad1.x = floor(blueColor) - (quad1.y * 8.0);
     
     highp vec2 quad2;
     quad2.y = floor(ceil(blueColor) / 8.0);
     quad2.x = ceil(blueColor) - (quad2.y * 8.0);
     
     highp vec2 texPos1;
     texPos1.x = (quad1.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * textureColor.r);
     texPos1.y = (quad1.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * textureColor.g);
     
     highp vec2 texPos2;
     texPos2.x = (quad2.x * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * textureColor.r);
     texPos2.y = (quad2.y * 0.125) + 0.5/512.0 + ((0.125 - 1.0/512.0) * textureColor.g);
     
     lowp vec4 newColor1 = texture2D(inputImageTexture2, texPos1);
     lowp vec4 newColor2 = texture2D(inputImageTexture2, texPos2);
     
     lowp vec4 newColor = mix(newColor1, newColor2, fract(blueColor));
     gl_FragColor = mix(textureColor, vec4(newColor.rgb, textureColor.w), intensity);
 }
 );

@interface DJILiveViewRenderLookupFilter ()
@end

@implementation DJILiveViewRenderLookupFilter

-(id) initWithContext:(DJILiveViewRenderContext *)acontext lookupTexture:(DJILiveViewRenderTexture *)texture{
    if (self = [super initWithContext:acontext
             fragmentShaderFromString:kDJIGPUImageLookupFragmentShaderString]) {
        
        self.lookupTexture = texture;
        self.intensity = 1.0;
    }
    return self;
}

-(void) setLookupTexture:(DJILiveViewRenderTexture *)lookupTexture{
    if (_lookupTexture == lookupTexture) {
        return;
    }
    
    _lookupTexture = lookupTexture;
    [self updateTexture];
}

-(void) setIntensity:(CGFloat)intensity{
    if (_intensity == intensity) {
        return;
    }
    
    _intensity = intensity;
    [self setFloat:intensity forUniformName:@"intensity"];
}

-(void) updateTexture{
    GLuint lookupTextureUniform = [filterProgram uniformIndex:@"inputImageTexture2"];
    
    __weak DJILiveViewRenderLookupFilter* target = self;
    [self setAndExecuteUniformStateCallbackAtIndex:lookupTextureUniform
                                        forProgram:filterProgram
                                           toBlock:
     ^{
         //use texture 2
         glActiveTexture(GL_TEXTURE0 + 1);
         glBindTexture(GL_TEXTURE_2D, target.lookupTexture.texture);
         glUniform1i(lookupTextureUniform, 1);
     }];
}

@end
