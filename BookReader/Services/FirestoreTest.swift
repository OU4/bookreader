//
//  FirestoreTest.swift
//  BookReader
//
//  Simple test to verify Firestore connection
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
class FirestoreTest {
    
    static func testConnection() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for test")
            return
        }
        
        print("🧪 Testing Firestore connection for user: \(userId)")
        
        let db = Firestore.firestore()
        
        // Test write
        let testData: [String: Any] = [
            "test": true,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userId
        ]
        
        db.collection("test").document("connection").setData(testData) { error in
            if let error = error {
                print("❌ Firestore write test failed: \(error)")
            } else {
                print("✅ Firestore write test successful")
                
                // Test read
                db.collection("test").document("connection").getDocument { document, error in
                    if let error = error {
                        print("❌ Firestore read test failed: \(error)")
                    } else if let document = document, document.exists {
                        print("✅ Firestore read test successful")
                        print("📄 Document data: \(document.data() ?? [:])")
                    } else {
                        print("❌ Firestore read test: Document does not exist")
                    }
                }
            }
        }
        
        // Test user collection access
        db.collection("users").document(userId).collection("books").getDocuments { snapshot, error in
            if let error = error {
                print("❌ User books collection access failed: \(error)")
            } else {
                print("✅ User books collection accessible. Found \(snapshot?.documents.count ?? 0) documents")
            }
        }
        
        // Test Firebase Storage
        testFirebaseStorage(userId: userId)
    }
    
    static func testFirebaseStorage(userId: String) {
        print("🧪 Testing Firebase Storage...")
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("test/\(userId)/test.txt")
        
        // Create test data
        let testData = "Hello Firebase Storage!".data(using: .utf8)!
        
        // Upload test data
        storageRef.putData(testData, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Storage upload test failed: \(error)")
            } else {
                print("✅ Storage upload test successful")
                print("📄 Metadata: \(metadata?.name ?? "unknown")")
                
                // Test download
                storageRef.getData(maxSize: 1024) { data, error in
                    if let error = error {
                        print("❌ Storage download test failed: \(error)")
                    } else if let data = data {
                        let content = String(data: data, encoding: .utf8) ?? "unknown"
                        print("✅ Storage download test successful: \(content)")
                    }
                }
            }
        }
    }
}
