//
//  OnScreenControls.m
//  Moonlight
//
//  Created by Diego Waxemberg on 12/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "OnScreenControls.h"
#import "ControllerSupport.h"
#import "Controller.h"
#include "Limelight.h"

#define UPDATE_BUTTON(x, y) (buttonFlags = \
(y) ? (buttonFlags | (x)) : (buttonFlags & ~(x)))

@implementation OnScreenControls {
    CALayer* _aButton;
    CALayer* _bButton;
    CALayer* _xButton;
    CALayer* _yButton;
    CALayer* _upButton;
    CALayer* _downButton;
    CALayer* _leftButton;
    CALayer* _rightButton;
    CALayer* _leftStickBackground;
    CALayer* _leftStick;
    CALayer* _rightStickBackground;
    CALayer* _rightStick;
    CALayer* _startButton;
    CALayer* _selectButton;
    CALayer* _r1Button;
    CALayer* _r2Button;
    CALayer* _r3Button;
    CALayer* _l1Button;
    CALayer* _l2Button;
    CALayer* _l3Button;
    CALayer* _edge;
    
    UITouch* _aTouch;
    UITouch* _bTouch;
    UITouch* _xTouch;
    UITouch* _yTouch;
    UITouch* _upTouch;
    UITouch* _downTouch;
    UITouch* _leftTouch;
    UITouch* _rightTouch;
    UITouch* _lsTouch;
    UITouch* _rsTouch;
    UITouch* _startTouch;
    UITouch* _selectTouch;
    UITouch* _r1Touch;
    UITouch* _r2Touch;
    UITouch* _r3Touch;
    UITouch* _l1Touch;
    UITouch* _l2Touch;
    UITouch* _l3Touch;
    UITouch* _edgeTouch;
    
    NSDate* l3TouchStart;
    NSDate* r3TouchStart;
    
    BOOL l3Set;
    BOOL r3Set;
    
    UIView* _view;
    OnScreenControlsLevel _level;
    
    ControllerSupport *_controllerSupport;
    Controller *_controller;
    id<EdgeDetectionDelegate> _edgeDelegate;
}

static const float EDGE_WIDTH = .1;

//static const float BUTTON_SIZE = 50;
static const float BUTTON_DIST = 20;
static float BUTTON_CENTER_X;
static float BUTTON_CENTER_Y;

static const float D_PAD_DIST = 15;
static float D_PAD_CENTER_X;
static float D_PAD_CENTER_Y;

static const double STICK_CLICK_RATE = 100;
static const float STICK_DEAD_ZONE = .1;
static float STICK_INNER_SIZE;
static float STICK_OUTER_SIZE;
static float LS_CENTER_X;
static float LS_CENTER_Y;
static float RS_CENTER_X;
static float RS_CENTER_Y;

static float START_X;
static float START_Y;

static float SELECT_X;
static float SELECT_Y;

static float R1_X;
static float R1_Y;
static float R2_X;
static float R2_Y;
static float R3_X;
static float R3_Y;
static float L1_X;
static float L1_Y;
static float L2_X;
static float L2_Y;
static float L3_X;
static float L3_Y;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport swipeDelegate:(id<EdgeDetectionDelegate>)swipeDelegate {
    self = [self init];
    _view = view;
    _controllerSupport = controllerSupport;
    _controller = [[Controller alloc] init];
    _controller.playerIndex = 0;
    _edgeDelegate = swipeDelegate;
    
    _aButton = [CALayer layer];
    _bButton = [CALayer layer];
    _xButton = [CALayer layer];
    _yButton = [CALayer layer];
    _upButton = [CALayer layer];
    _downButton = [CALayer layer];
    _leftButton = [CALayer layer];
    _rightButton = [CALayer layer];
    _l1Button = [CALayer layer];
    _r1Button = [CALayer layer];
    _l2Button = [CALayer layer];
    _r2Button = [CALayer layer];
    _l3Button = [CALayer layer];
    _r3Button = [CALayer layer];
    _startButton = [CALayer layer];
    _selectButton = [CALayer layer];
    _leftStickBackground = [CALayer layer];
    _rightStickBackground = [CALayer layer];
    _leftStick = [CALayer layer];
    _rightStick = [CALayer layer];
    _edge = [CALayer layer];

    [self setupEdgeDetection];
    
    return self;
}

- (void) setLevel:(OnScreenControlsLevel)level {
    _level = level;
    [self updateControls];
}

- (void) updateControls {
    switch (_level) {
        case OnScreenControlsLevelOff:
            [self hideButtons];
            [self hideBumpers];
            [self hideTriggers];
            [self hideStartSelect];
            [self hideSticks];
            [self hideL3R3];
            break;
        case OnScreenControlsLevelAutoGCGamepad:
            // GCGamepad is missing triggers, both analog sticks,
            // and the select button
            [self setupGamepadControls];
            
            [self hideButtons];
            [self hideBumpers];
            [self drawTriggers];
            [self drawStartSelect];
            [self drawSticks];
            [self drawL3R3];
            break;
        case OnScreenControlsLevelAutoGCExtendedGamepad:
            // GCExtendedGamepad is missing R3, L3, and select
            [self setupExtendedGamepadControls];
            
            [self hideButtons];
            [self hideBumpers];
            [self hideTriggers];
            [self drawStartSelect];
            [self hideSticks];
            [self drawL3R3];
            break;
        case OnScreenControlsLevelSimple:
            [self setupSimpleControls];
            
            [self drawTriggers];
            [self drawStartSelect];
            [self drawL3R3];
            [self hideButtons];
            [self hideBumpers];
            [self hideSticks];
            break;
        case OnScreenControlsLevelFull:
            [self setupComplexControls];
            
            [self drawButtons];
            [self drawStartSelect];
            [self drawBumpers];
            [self drawTriggers];
            [self drawSticks];
            [self hideL3R3]; // Full controls don't need these they have the sticks
            break;
        default:
            Log(LOG_W, @"Unknown on-screen controls level: %d", (int)_level);
            break;
    }
}

- (void) setupEdgeDetection {
    _edge.frame = CGRectMake(0, 0, _view.frame.size.width * EDGE_WIDTH, _view.frame.size.height);
    [_view.layer addSublayer:_edge];
}

// For GCExtendedGamepad controls we move start, select, L3, and R3 to the button
- (void) setupExtendedGamepadControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    START_Y = _view.frame.size.height * .9;
    SELECT_Y = _view.frame.size.height * .9;
}

// For GCGamepad controls we move triggers, start, and select
// to sit right above the analog sticks
- (void) setupGamepadControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    // TODO
}

// For simple controls we move the triggers and buttons to the bottom
- (void) setupSimpleControls {
    // Start with the default complex layout
    [self setupComplexControls];
    
    START_Y = _view.frame.size.height * .9;
    SELECT_Y = _view.frame.size.height * .9;

    L1_Y = _view.frame.size.height * .7;
    L2_Y = _view.frame.size.height * .9;
    L2_X = _view.frame.size.width * .1;
    R1_Y = _view.frame.size.height * .7;
    R2_Y = _view.frame.size.height * .9;
    R2_X = _view.frame.size.width * .9;
}

- (void) setupComplexControls
{
    D_PAD_CENTER_X = _view.frame.size.width * .15;
    D_PAD_CENTER_Y = _view.frame.size.height * .55;
    BUTTON_CENTER_X = _view.frame.size.width * .85;
    BUTTON_CENTER_Y = _view.frame.size.height * .55;
    
    LS_CENTER_X = _view.frame.size.width * .35;
    LS_CENTER_Y = _view.frame.size.height * .75;
    RS_CENTER_X = _view.frame.size.width * .65;
    RS_CENTER_Y = _view.frame.size.height * .75;
    
    START_X = _view.frame.size.width * .6;
    START_Y = _view.frame.size.height * .1;
    SELECT_X = _view.frame.size.width * .4;
    SELECT_Y = _view.frame.size.height * .1;
    
    L1_X = _view.frame.size.width * .15;
    L1_Y = _view.frame.size.height * .27;
    L2_X = _view.frame.size.width * .15;
    L2_Y = _view.frame.size.height * .1;
    R1_X = _view.frame.size.width * .85;
    R1_Y = _view.frame.size.height * .27;
    R2_X = _view.frame.size.width * .85;
    R2_Y = _view.frame.size.height * .1;
    L3_X = _view.frame.size.width * .25;
    L3_Y = _view.frame.size.height * .75;
    R3_X = _view.frame.size.width * .75;
    R3_Y = _view.frame.size.height * .75;
}

- (void) drawButtons {
    // create A button
    UIImage* aButtonImage = [UIImage imageNamed:@"AButton"];
    _aButton.contents = (id) aButtonImage.CGImage;
    _aButton.frame = CGRectMake(BUTTON_CENTER_X - aButtonImage.size.width / 2, BUTTON_CENTER_Y + BUTTON_DIST, aButtonImage.size.width, aButtonImage.size.height);
    [_view.layer addSublayer:_aButton];

    // create B button
    UIImage* bButtonImage = [UIImage imageNamed:@"BButton"];
    _bButton.frame = CGRectMake(BUTTON_CENTER_X + BUTTON_DIST, BUTTON_CENTER_Y - bButtonImage.size.height / 2, bButtonImage.size.width, bButtonImage.size.height);
    _bButton.contents = (id) bButtonImage.CGImage;
    [_view.layer addSublayer:_bButton];

    // create X Button
    UIImage* xButtonImage = [UIImage imageNamed:@"XButton"];
    _xButton.frame = CGRectMake(BUTTON_CENTER_X - BUTTON_DIST - xButtonImage.size.width, BUTTON_CENTER_Y - xButtonImage.size.height/ 2, xButtonImage.size.width, xButtonImage.size.height);
    _xButton.contents = (id) xButtonImage.CGImage;
    [_view.layer addSublayer:_xButton];

    // create Y Button
    UIImage* yButtonImage = [UIImage imageNamed:@"YButton"];
    _yButton.frame = CGRectMake(BUTTON_CENTER_X - yButtonImage.size.width / 2, BUTTON_CENTER_Y - BUTTON_DIST - yButtonImage.size.height, yButtonImage.size.width, yButtonImage.size.height);
    _yButton.contents = (id) yButtonImage.CGImage;
    [_view.layer addSublayer:_yButton];

    // create Down button
    UIImage* downButtonImage = [UIImage imageNamed:@"DownButton"];
    _downButton.frame = CGRectMake(D_PAD_CENTER_X - downButtonImage.size.width / 2, D_PAD_CENTER_Y + D_PAD_DIST, downButtonImage.size.width, downButtonImage.size.height);
    _downButton.contents = (id) downButtonImage.CGImage;
    [_view.layer addSublayer:_downButton];

    // create Right button
    UIImage* rightButtonImage = [UIImage imageNamed:@"RightButton"];
    _rightButton.frame = CGRectMake(D_PAD_CENTER_X + D_PAD_DIST, D_PAD_CENTER_Y - rightButtonImage.size.height / 2, rightButtonImage.size.width, rightButtonImage.size.height);
    _rightButton.contents = (id) rightButtonImage.CGImage;
    [_view.layer addSublayer:_rightButton];

    // create Up button
    UIImage* upButtonImage = [UIImage imageNamed:@"UpButton"];
    _upButton.frame = CGRectMake(D_PAD_CENTER_X - upButtonImage.size.width / 2, D_PAD_CENTER_Y - D_PAD_DIST - upButtonImage.size.height, upButtonImage.size.width, upButtonImage.size.height);
    _upButton.contents = (id) upButtonImage.CGImage;
    [_view.layer addSublayer:_upButton];

    // create Left button
    UIImage* leftButtonImage = [UIImage imageNamed:@"LeftButton"];
    _leftButton.frame = CGRectMake(D_PAD_CENTER_X - D_PAD_DIST - leftButtonImage.size.width, D_PAD_CENTER_Y - leftButtonImage.size.height / 2, leftButtonImage.size.width, leftButtonImage.size.height);
    _leftButton.contents = (id) leftButtonImage.CGImage;
    [_view.layer addSublayer:_leftButton];
}

- (void) drawStartSelect {
    // create Start button
    UIImage* startButtonImage = [UIImage imageNamed:@"StartButton"];
    _startButton.frame = CGRectMake(START_X - startButtonImage.size.width / 2, START_Y - startButtonImage.size.height / 2, startButtonImage.size.width, startButtonImage.size.height);
    _startButton.contents = (id) startButtonImage.CGImage;
    [_view.layer addSublayer:_startButton];

    // create Select button
    UIImage* selectButtonImage = [UIImage imageNamed:@"SelectButton"];
    _selectButton.frame = CGRectMake(SELECT_X - selectButtonImage.size.width / 2, SELECT_Y - selectButtonImage.size.height / 2, selectButtonImage.size.width, selectButtonImage.size.height);
    _selectButton.contents = (id) selectButtonImage.CGImage;
    [_view.layer addSublayer:_selectButton];
}

- (void) drawBumpers {
    // create L1 button
    UIImage* l1ButtonImage = [UIImage imageNamed:@"L1"];
    _l1Button.frame = CGRectMake(L1_X - l1ButtonImage.size.width / 2, L1_Y - l1ButtonImage.size.height / 2, l1ButtonImage.size.width, l1ButtonImage.size.height);
    _l1Button.contents = (id) l1ButtonImage.CGImage;
    [_view.layer addSublayer:_l1Button];
    
    // create R1 button
    UIImage* r1ButtonImage = [UIImage imageNamed:@"R1"];
    _r1Button.frame = CGRectMake(R1_X - r1ButtonImage.size.width / 2, R1_Y - r1ButtonImage.size.height / 2, r1ButtonImage.size.width, r1ButtonImage.size.height);
    _r1Button.contents = (id) r1ButtonImage.CGImage;
    [_view.layer addSublayer:_r1Button];
}

- (void) drawTriggers {
    // create L2 button
    UIImage* l2ButtonImage = [UIImage imageNamed:@"L2"];
    _l2Button.frame = CGRectMake(L2_X - l2ButtonImage.size.width / 2, L2_Y - l2ButtonImage.size.height / 2, l2ButtonImage.size.width, l2ButtonImage.size.height);
    _l2Button.contents = (id) l2ButtonImage.CGImage;
    [_view.layer addSublayer:_l2Button];
    
    // create R2 button
    UIImage* r2ButtonImage = [UIImage imageNamed:@"R2"];
    _r2Button.frame = CGRectMake(R2_X - r2ButtonImage.size.width / 2, R2_Y - r2ButtonImage.size.height / 2, r2ButtonImage.size.width, r2ButtonImage.size.height);
    _r2Button.contents = (id) r2ButtonImage.CGImage;
    [_view.layer addSublayer:_r2Button];
}

- (void) drawSticks {
    // create left analog stick
    UIImage* leftStickBgImage = [UIImage imageNamed:@"StickOuter"];
    _leftStickBackground.frame = CGRectMake(LS_CENTER_X - leftStickBgImage.size.width / 2, LS_CENTER_Y - leftStickBgImage.size.height / 2, leftStickBgImage.size.width, leftStickBgImage.size.height);
    _leftStickBackground.contents = (id) leftStickBgImage.CGImage;
    [_view.layer addSublayer:_leftStickBackground];
    
    UIImage* leftStickImage = [UIImage imageNamed:@"StickInner"];
    _leftStick.frame = CGRectMake(LS_CENTER_X - leftStickImage.size.width / 2, LS_CENTER_Y - leftStickImage.size.height / 2, leftStickImage.size.width, leftStickImage.size.height);
    _leftStick.contents = (id) leftStickImage.CGImage;
    [_view.layer addSublayer:_leftStick];

    // create right analog stick
    UIImage* rightStickBgImage = [UIImage imageNamed:@"StickOuter"];
    _rightStickBackground.frame = CGRectMake(RS_CENTER_X - rightStickBgImage.size.width / 2, RS_CENTER_Y - rightStickBgImage.size.height / 2, rightStickBgImage.size.width, rightStickBgImage.size.height);
    _rightStickBackground.contents = (id) rightStickBgImage.CGImage;
    [_view.layer addSublayer:_rightStickBackground];
    
    UIImage* rightStickImage = [UIImage imageNamed:@"StickInner"];
    _rightStick.frame = CGRectMake(RS_CENTER_X - rightStickImage.size.width / 2, RS_CENTER_Y - rightStickImage.size.height / 2, rightStickImage.size.width, rightStickImage.size.height);
    _rightStick.contents = (id) rightStickImage.CGImage;
    [_view.layer addSublayer:_rightStick];
    
    STICK_INNER_SIZE = rightStickImage.size.width;
    STICK_OUTER_SIZE = rightStickBgImage.size.width;
}

- (void) drawL3R3 {
    UIImage* l3ButtonImage = [UIImage imageNamed:@"L3"];
    _l3Button.frame = CGRectMake(L3_X - l3ButtonImage.size.width / 2, L3_Y - l3ButtonImage.size.height / 2, l3ButtonImage.size.width, l3ButtonImage.size.height);
    _l3Button.contents = (id) l3ButtonImage.CGImage;
    _l3Button.cornerRadius = l3ButtonImage.size.width / 2;
    _l3Button.borderColor = [UIColor colorWithRed:15.f/255 green:160.f/255 blue:40.f/255 alpha:1.f].CGColor;
    [_view.layer addSublayer:_l3Button];
    
    UIImage* r3ButtonImage = [UIImage imageNamed:@"R3"];
    _r3Button.frame = CGRectMake(R3_X - r3ButtonImage.size.width / 2, R3_Y - r3ButtonImage.size.height / 2, r3ButtonImage.size.width, r3ButtonImage.size.height);
    _r3Button.contents = (id) r3ButtonImage.CGImage;
    _r3Button.cornerRadius = r3ButtonImage.size.width / 2;
    _r3Button.borderColor = [UIColor colorWithRed:15.f/255 green:160.f/255 blue:40.f/255 alpha:1.f].CGColor;
    [_view.layer addSublayer:_r3Button];
}

- (void) hideButtons {
    [_aButton removeFromSuperlayer];
    [_bButton removeFromSuperlayer];
    [_xButton removeFromSuperlayer];
    [_yButton removeFromSuperlayer];
    [_upButton removeFromSuperlayer];
    [_downButton removeFromSuperlayer];
    [_leftButton removeFromSuperlayer];
    [_rightButton removeFromSuperlayer];
}

- (void) hideStartSelect {
    [_startButton removeFromSuperlayer];
    [_selectButton removeFromSuperlayer];
}

- (void) hideBumpers {
    [_l1Button removeFromSuperlayer];
    [_r1Button removeFromSuperlayer];
}

- (void) hideTriggers {
    [_l2Button removeFromSuperlayer];
    [_r2Button removeFromSuperlayer];
}

- (void) hideSticks {
    [_leftStickBackground removeFromSuperlayer];
    [_rightStickBackground removeFromSuperlayer];
    [_leftStick removeFromSuperlayer];
    [_rightStick removeFromSuperlayer];
}

- (void) hideL3R3 {
    [_l3Button removeFromSuperlayer];
    [_r3Button removeFromSuperlayer];
}

- (BOOL) handleTouchMovedEvent:touches {
    BOOL updated = false;
    BOOL buttonTouch = false;
    float rsMaxX = RS_CENTER_X + STICK_OUTER_SIZE / 2;
    float rsMaxY = RS_CENTER_Y + STICK_OUTER_SIZE / 2;
    float rsMinX = RS_CENTER_X - STICK_OUTER_SIZE / 2;
    float rsMinY = RS_CENTER_Y - STICK_OUTER_SIZE / 2;
    float lsMaxX = LS_CENTER_X + STICK_OUTER_SIZE / 2;
    float lsMaxY = LS_CENTER_Y + STICK_OUTER_SIZE / 2;
    float lsMinX = LS_CENTER_X - STICK_OUTER_SIZE / 2;
    float lsMinY = LS_CENTER_Y - STICK_OUTER_SIZE / 2;

    for (UITouch* touch in touches) {
        CGPoint touchLocation = [touch locationInView:_view];
        float xLoc = touchLocation.x;
        float yLoc = touchLocation.y;
        if (touch == _lsTouch) {
            if (xLoc > lsMaxX) xLoc = lsMaxX;
            if (xLoc < lsMinX) xLoc = lsMinX;
            if (yLoc > lsMaxY) yLoc = lsMaxY;
            if (yLoc < lsMinY) yLoc = lsMinY;

            _leftStick.frame = CGRectMake(xLoc - STICK_INNER_SIZE / 2, yLoc - STICK_INNER_SIZE / 2, STICK_INNER_SIZE, STICK_INNER_SIZE);

            float xStickVal = (xLoc - LS_CENTER_X) / (lsMaxX - LS_CENTER_X);
            float yStickVal = (yLoc - LS_CENTER_Y) / (lsMaxY - LS_CENTER_Y);

            if (fabsf(xStickVal) < STICK_DEAD_ZONE) xStickVal = 0;
            if (fabsf(yStickVal) < STICK_DEAD_ZONE) yStickVal = 0;

            [_controllerSupport updateLeftStick:_controller x:0x7FFE * xStickVal y:0x7FFE * -yStickVal];

            updated = true;
        } else if (touch == _rsTouch) {
            if (xLoc > rsMaxX) xLoc = rsMaxX;
            if (xLoc < rsMinX) xLoc = rsMinX;
            if (yLoc > rsMaxY) yLoc = rsMaxY;
            if (yLoc < rsMinY) yLoc = rsMinY;

            _rightStick.frame = CGRectMake(xLoc - STICK_INNER_SIZE / 2, yLoc - STICK_INNER_SIZE / 2, STICK_INNER_SIZE, STICK_INNER_SIZE);

            float xStickVal = (xLoc - RS_CENTER_X) / (rsMaxX - RS_CENTER_X);
            float yStickVal = (yLoc - RS_CENTER_Y) / (rsMaxY - RS_CENTER_Y);

            if (fabsf(xStickVal) < STICK_DEAD_ZONE) xStickVal = 0;
            if (fabsf(yStickVal) < STICK_DEAD_ZONE) yStickVal = 0;

            [_controllerSupport updateRightStick:_controller x:0x7FFE * xStickVal y:0x7FFE * -yStickVal];

            updated = true;
        } else if (touch == _aTouch) {
            buttonTouch = true;
        } else if (touch == _bTouch) {
            buttonTouch = true;
        } else if (touch == _xTouch) {
            buttonTouch = true;
        } else if (touch == _yTouch) {
            buttonTouch = true;
        } else if (touch == _upTouch) {
            buttonTouch = true;
        } else if (touch == _downTouch) {
            buttonTouch = true;
        } else if (touch == _leftTouch) {
            buttonTouch = true;
        } else if (touch == _rightTouch) {
            buttonTouch = true;
        } else if (touch == _startTouch) {
            buttonTouch = true;
        } else if (touch == _selectTouch) {
            buttonTouch = true;
        } else if (touch == _l1Touch) {
            buttonTouch = true;
        } else if (touch == _r1Touch) {
            buttonTouch = true;
        } else if (touch == _l2Touch) {
            buttonTouch = true;
        } else if (touch == _r2Touch) {
            buttonTouch = true;
        } else if (touch == _l3Touch) {
            buttonTouch = true;
        } else if (touch == _r3Touch) {
            buttonTouch = true;
        }
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller];
    }
    return updated || buttonTouch;
}

- (BOOL)handleTouchDownEvent:touches {
    BOOL updated = false;
    BOOL stickTouch = false;
    for (UITouch* touch in touches) {
        CGPoint touchLocation = [touch locationInView:_view];
        
        if ([_aButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:A_FLAG];
            _aTouch = touch;
            updated = true;
        } else if ([_bButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:B_FLAG];
            _bTouch = touch;
            updated = true;
        } else if ([_xButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:X_FLAG];
            _xTouch = touch;
            updated = true;
        } else if ([_yButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:Y_FLAG];
            _yTouch = touch;
            updated = true;
        } else if ([_upButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:UP_FLAG];
            _upTouch = touch;
            updated = true;
        } else if ([_downButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:DOWN_FLAG];
            _downTouch = touch;
            updated = true;
        } else if ([_leftButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:LEFT_FLAG];
            _leftTouch = touch;
            updated = true;
        } else if ([_rightButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:RIGHT_FLAG];
            _rightTouch = touch;
            updated = true;
        } else if ([_startButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:PLAY_FLAG];
            _startTouch = touch;
            updated = true;
        } else if ([_selectButton.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:BACK_FLAG];
            _selectTouch = touch;
            updated = true;
        } else if ([_l1Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:LB_FLAG];
            _l1Touch = touch;
            updated = true;
        } else if ([_r1Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport setButtonFlag:_controller flags:RB_FLAG];
            _r1Touch = touch;
            updated = true;
        } else if ([_l2Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport updateLeftTrigger:_controller left:0xFF];
            _l2Touch = touch;
            updated = true;
        } else if ([_r2Button.presentationLayer hitTest:touchLocation]) {
            [_controllerSupport updateRightTrigger:_controller right:0xFF];
            _r2Touch = touch;
            updated = true;
        } else if ([_l3Button.presentationLayer hitTest:touchLocation]) {
            if (l3Set) {
                [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
                _l3Button.borderWidth = 0.0f;
            } else {
                [_controllerSupport setButtonFlag:_controller flags:LS_CLK_FLAG];
                _l3Button.borderWidth = 2.0f;
            }
            l3Set = !l3Set;
            _l3Touch = touch;
            updated = true;
        } else if ([_r3Button.presentationLayer hitTest:touchLocation]) {
            if (r3Set) {
                [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
                _r3Button.borderWidth = 0.0f;
            } else {
                [_controllerSupport setButtonFlag:_controller flags:RS_CLK_FLAG];
                _r3Button.borderWidth = 2.0f;
            }
            r3Set = !r3Set;
            _r3Touch = touch;
            updated = true;
        } else if ([_leftStick.presentationLayer hitTest:touchLocation]) {
            if (l3TouchStart != nil) {
                // Find elapsed time and convert to milliseconds
                // Use (-) modifier to conversion since receiver is earlier than now
                double l3TouchTime = [l3TouchStart timeIntervalSinceNow] * -1000.0;
                if (l3TouchTime < STICK_CLICK_RATE) {
                    [_controllerSupport setButtonFlag:_controller flags:LS_CLK_FLAG];
                    updated = true;
                }
            }
            _lsTouch = touch;
            stickTouch = true;
        } else if ([_rightStick.presentationLayer hitTest:touchLocation]) {
            if (r3TouchStart != nil) {
                // Find elapsed time and convert to milliseconds
                // Use (-) modifier to conversion since receiver is earlier than now
                double r3TouchTime = [r3TouchStart timeIntervalSinceNow] * -1000.0;
                if (r3TouchTime < STICK_CLICK_RATE) {
                    [_controllerSupport setButtonFlag:_controller flags:RS_CLK_FLAG];
                    updated = true;
                }
            }
            _rsTouch = touch;
            stickTouch = true;
        } else if ([_edge.presentationLayer hitTest:touchLocation]) {
            _edgeTouch = touch;
        }
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller];
    }
    return updated || stickTouch;
}

- (BOOL)handleTouchUpEvent:touches {
    BOOL updated = false;
    BOOL touched = false;
    for (UITouch* touch in touches) {
        if (touch == _aTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:A_FLAG];
            _aTouch = nil;
            updated = true;
        } else if (touch == _bTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:B_FLAG];
            _bTouch = nil;
            updated = true;
        } else if (touch == _xTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:X_FLAG];
            _xTouch = nil;
            updated = true;
        } else if (touch == _yTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:Y_FLAG];
            _yTouch = nil;
            updated = true;
        } else if (touch == _upTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:UP_FLAG];
            _upTouch = nil;
            updated = true;
        } else if (touch == _downTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:DOWN_FLAG];
            _downTouch = nil;
            updated = true;
        } else if (touch == _leftTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:LEFT_FLAG];
            _leftTouch = nil;
            updated = true;
        } else if (touch == _rightTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:RIGHT_FLAG];
            _rightTouch = nil;
            updated = true;
        } else if (touch == _startTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:PLAY_FLAG];
            _startTouch = nil;
            updated = true;
        } else if (touch == _selectTouch) {
            [_controllerSupport clearButtonFlag:_controller flags:BACK_FLAG];
            _selectTouch = nil;
            updated = true;
        } else if (touch == _l1Touch) {
            [_controllerSupport clearButtonFlag:_controller flags:LB_FLAG];
            _l1Touch = nil;
            updated = true;
        } else if (touch == _r1Touch) {
            [_controllerSupport clearButtonFlag:_controller flags:RB_FLAG];
            _r1Touch = nil;
            updated = true;
        } else if (touch == _l2Touch) {
            [_controllerSupport updateLeftTrigger:_controller left:0];
            _l2Touch = nil;
            updated = true;
        } else if (touch == _r2Touch) {
            [_controllerSupport updateRightTrigger:_controller right:0];
            _r2Touch = nil;
            updated = true;
        } else if (touch == _lsTouch) {
            _leftStick.frame = CGRectMake(LS_CENTER_X - STICK_INNER_SIZE / 2, LS_CENTER_Y - STICK_INNER_SIZE / 2, STICK_INNER_SIZE, STICK_INNER_SIZE);
            [_controllerSupport updateLeftStick:_controller x:0 y:0];
            [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
            l3TouchStart = [NSDate date];
            _lsTouch = nil;
            updated = true;
        } else if (touch == _rsTouch) {
            _rightStick.frame = CGRectMake(RS_CENTER_X - STICK_INNER_SIZE / 2, RS_CENTER_Y - STICK_INNER_SIZE / 2, STICK_INNER_SIZE, STICK_INNER_SIZE);
            [_controllerSupport updateRightStick:_controller x:0 y:0];
            [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
            r3TouchStart = [NSDate date];
            _rsTouch = nil;
            updated = true;
        }
        else if (touch == _l3Touch) {
            _l3Touch = nil;
            touched = true;
        }
        else if (touch == _r3Touch) {
            _r3Touch = nil;
            touched = true;
        } else if (touch == _edgeTouch) {
            _edgeTouch = nil;
            if (![_edge.presentationLayer hitTest:[touch locationInView:_view]]) {
                [_edgeDelegate edgeSwiped];
            }
        }
    }
    if (updated) {
        [_controllerSupport updateFinished:_controller];
    }
    return updated || touched;
}

@end
