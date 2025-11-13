// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShapeCore",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ShapeCore",
            targets: ["ShapeCore"]
        ),
    ],
    dependencies: [
        // ✅ Firebaseの依存関係を追加
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.4.0")
    ],
    targets: [
        .target(
            name: "ShapeCore",
            dependencies: [
                // ✅ ShapeCoreでFirebaseを直接使えるようにする
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk")
            ]
        )
    ]
)
