# DALI

[![CI Status](https://travis-ci.org/dali-lab/DALI-Framework.svg?branch=master)](https://travis-ci.org/dali-lab/DALI-Framework)
[![Version](https://img.shields.io/cocoapods/v/DALI.svg?style=flat)](http://cocoapods.org/pods/DALI)
[![License](https://img.shields.io/cocoapods/l/DALI.svg?style=flat)](http://cocoapods.org/pods/DALI)
[![Platform](https://img.shields.io/cocoapods/p/DALI.svg?style=flat)](http://cocoapods.org/pods/DALI)

A framework used by DALI Lab members to access the internal API, which stores all information about DALI's projects, members, and events.

## Getting Started

### Authenticate
The API protects its data using two methods: private API key and Google OAuth2. This is done to support two different use cases: static installment or user-personal device.

##### Google OAuth2 (User-Personal)

##### API Key Auth (Static-Installment)
A static-installment product could be an Apple TV app, a kiosk-type desktop application, or even another server that runs some other service. Its up to your imagination 😀!

_Qualifications:_
- The application does not act on behalf of any single member
- The application does not need to modify member information

_Authenticating Using API Key:_
1. Contact an API administrator to register for an API key to be made for your app.
  - The key's access will be limited to the routes you need, but you can request more routes later if you need them
  - Keep the key you get secret! It is an all access pass to the routes you were granted
2. Create a plist file (sample shown below) to store the key and add it to .gitignore
![envFile](./images/envFile.png)
3. Load the file and load the config:
```swift
let file = NSDictionary(contentsOfFile: "path/to/your/file.plist")
let config = DALIConfig(dict: file)
```
4. Configure the API with your credentials
```swift
// ...
let config = DALIConfig(dict: file)
DALIapi.configure(config)
```

## Installation

DALI is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "DALI"
```

## Example
> Example project is still in alpha

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Author

John Kotz, john.kotz@dali.dartmouth.edu

## Requirements
##### Usage Requirements
You must be a member of the DALI Lab or be working on behalf (with the permission) of the DALI Lab to use this pod. By using this cocoapod you acknowledge this requirement.

##### Dependencies
- SwiftJSON

##### Function Specific Requirements
Some routes will intentionally crash your app if you use them without proper permission. Check out the docs on [Protected Functions]().

## License

DALI is available under the MIT license. See the LICENSE file for more info.
