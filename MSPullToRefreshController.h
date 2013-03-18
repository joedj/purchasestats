//
//  MSPullToRefreshController.h
//
//  Created by John Wu on 3/5/12.
//  Copyright (c) 2012 TFM. All rights reserved.
//

/**************************||||-ABSTRACT-||||**********************************
 *
 *  This is the a generic pull-to-refresh library.
 *
 *  This library attempts to abstract away the core pull-
 *  to-refresh logic, and allow the users to implement custom
 *  views on top and update them at key points in the refresh cycle.
 *
 *  Hence, this class is NOT meant to be used directly. You
 *  are meant to write a wrapper which uses this class to implement
 *  your own pull-to-refresh solutions.
 *
 *  Instead of overriding the delegate like most PTF libraries,
 *  we merely observe the contentOffset property of the scrollview
 *  using KVO.
 *
 *  This library allows refreshing in any direction and/or any combination
 *  of directions.
 *
 *  It is up to the user to inform the library when to end a refresh sequence
 *  for each direction.
 *
 *  Do NOT use a scrollview with a contentSize that is smaller than the frame.
 *
 *
 ******************************************************************************/

 /**
 * flags that determine the directions that can be engaged.
 */
typedef enum {
    MSRefreshableDirectionNone    = 0,
    MSRefreshableDirectionTop     = 1 << 0,
    MSRefreshableDirectionLeft    = 1 << 1,
    MSRefreshableDirectionBottom  = 1 << 2,
    MSRefreshableDirectionRight   = 1 << 3
} MSRefreshableDirections;

/**
 * flags that determine the directions that are currently refreshing.
 */
typedef enum {
    MSRefreshingDirectionNone    = 0,
    MSRefreshingDirectionTop     = 1 << 0,
    MSRefreshingDirectionLeft    = 1 << 1,
    MSRefreshingDirectionBottom  = 1 << 2,
    MSRefreshingDirectionRight   = 1 << 3
} MSRefreshingDirections;

/**
 * simple enum that specifies the direction related to delegate callbacks.
 */
typedef enum {
    MSRefreshDirectionTop = 0,
    MSRefreshDirectionLeft,
    MSRefreshDirectionBottom,
    MSRefreshDirectionRight
} MSRefreshDirection;

@protocol PurchaseStatsMSPullToRefreshDelegate;

@interface PurchaseStatsMSPullToRefreshController : NSObject

/*
 * the only constructor you should use.
 * pass in the scrollview to be observed and
 * the delegate to receive call backs
 */
- (id) initWithScrollView:(UIScrollView *)scrollView delegate:(id <PurchaseStatsMSPullToRefreshDelegate>)delegate;

/*
 * Call this function with a direction to end the refresh sequence
 * in that direction. With or without animation.
 */
- (void) finishRefreshingDirection:(MSRefreshDirection)direction animated:(BOOL)animated;

/*
 * calls the above with animated = NO
 */
- (void) finishRefreshingDirection:(MSRefreshDirection)direction;

/*
 * Programmatically start a refresh in the given direction, animated or not.
 */
- (void) startRefreshingDirection:(MSRefreshDirection)direction animated:(BOOL)animated;

/*
 * calls the above with animated = NO
 */
- (void) startRefreshingDirection:(MSRefreshDirection)direction;

@end

@protocol PurchaseStatsMSPullToRefreshDelegate <NSObject>

@required

/*
 * asks the delegate which refresh directions it would like enabled
 */
- (BOOL) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *) controller canRefreshInDirection:(MSRefreshDirection)direction;

/*
 * inset threshold to engage refresh
 */
- (CGFloat) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *) controller refreshableInsetForDirection:(MSRefreshDirection) direction;

/*
 * inset that the direction retracts back to after refresh started
 */
- (CGFloat) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller refreshingInsetForDirection:(MSRefreshDirection)direction;

@optional

/*
 * informs the delegate that lifting your finger will trigger a refresh
 * in that direction. This is only called when you cross the refreshable
 * offset defined in the respective MSInflectionOffsets.
 */
- (void) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *) controller canEngageRefreshDirection:(MSRefreshDirection) direction;

/*
 * informs the delegate that lifting your finger will NOT trigger a refresh
 * in that direction. This is only called when you cross the refreshable
 * offset defined in the respective MSInflectionOffsets.
 */
- (void) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *) controller didDisengageRefreshDirection:(MSRefreshDirection) direction;

/*
 * informs the delegate that refresh sequence has been started by the user
 * in the specified direction. A good place to start any async work.
 */
- (void) pullToRefreshController:(PurchaseStatsMSPullToRefreshController *) controller didEngageRefreshDirection:(MSRefreshDirection) direction;


@end
