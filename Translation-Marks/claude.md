# Translation Marks App

- A native macOS App
- Using SwiftUI
- Using the First Party menu extra framework

- Always build the project to test for errors

# How it works

- The app is running in the background as status bar app
- It is invoked on pressing a keyboard shortcut CTRL + OPTION + CMD + t

When the shortcut is pressed:
- I can draw a rectangle on the screen with the mouse to make a screenshot of the area
- The screen is then processed using the vision framework to extract any text contained

Mark up selection
- Save the screenshot for debuggin in the "~/Documents/Screenshots" folder
- Detect areas with text.
- Draw a rectangle over those areas. Save marked up version of the screenshot
- Read the original text out load

Translate
- Detect the language.
- If it isn't english, Translate the text to English
- Read out aloud the English translation
