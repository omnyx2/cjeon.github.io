---
layout: post
title: Defect in Android api 24+ split screen and how to work around the bug
---

# What is it?

The defect happens when (the condition might not be exact, since I did not check the source codes)

1. There are three activities in a task,
2. The top activity calls `finish()` on itself, followed by the second activity calling `finish()` on itself
3. While the app is in split screen mode
4. And the app is not having focus during the above process happens.

What is expected then is that the only remaining activity calls any of `onResume` or `onStart` or even `onCreate` to draw view of the running application. However, what really happens is that the only remaining activity does not call any of the three, resulting in app looking like crashed. 

[Video](https://youtu.be/6vGEFE2u2Z0)

The sample code used in above video is available at [this repository](https://github.com/cjeon/SplitScreenTest).

The defact was reported at Jan 2th 2016, and Google said below on Jan 3th. [link](https://code.google.com/p/android/issues/detail?id=231337) 

> ```
> Hi,
> We have passed this defect on to the development team and will update this issue with more information as it becomes available.
> Thanks
> ```

# The work around

## In words

Since I cannot just sit and wait until the bug fixes or official guidance is provided, I made a simple work around. It is not perfect because it changes user story and affects user experience, however I thought work around was better than nothing.

1. Since the bug happens under special condition - where the activity is destroyed without user action, **it is normal to (and we should) notify the user**. In my case, we notified user with a toast like "The server closed connection".
2. Since the bug happens only when the problematic app is not activated, or focused, the answer is simple. We need to **activate the app** before the bug happens. A simple touch will do.
3. So, combining 1 and 2, **I changed the toast (which disapperas without user action) to a dialog (which needs user click to disappear). And changed the code a little so that the activity distroies itself only after user clicks the dialog.**

This way, we can avoid troublesome case without changing lots of codes.

## In code

### Before

```java
@Override
public void onResume() {
  super.onResume();
}

@Override
public void onPause() {
  super.onPause();
}

private void callFinish() {
  finish();
}
```

### After

(*below is pseudo-code)

```java
private boolean paused = false;

@Override
public void onResume() {
  super.onResume();
  paused = false;
}

@Override
public void onPause() {
  super.onPause();
  paused = true;
}

private void callFinish() {
  // work-around for split screen bug
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && getActivity().isInMultiWindowMode() && paused) {
    Dialog dialog = new MyDialog(
      "Server closed connection", 
      "OK", 
      ()-> finish()
    );
    dialog.show();
  } else {
    finish();
  }
}
```

Notes:

1. `MyDialog` is not an actual class. I used my dialog class in my code.
2. Checking `paused()` state is not necessary. However, I did so to minimize impact of the work-around code. The bug does not happen when the activity has the focus, so.


_______

Thank you for reading and hope this can save you some time. 
