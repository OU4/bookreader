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
            return
        }
        
        
        let db = Firestore.firestore()
        
        // Test write
        let testData: [String: Any] = [
            "test": true,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userId
        ]
        
        db.collection("test").document("connection").setData(testData) { error in
            if let error = error {
            } else {
                
                // Test read
                db.collection("test").document("connection").getDocument { document, error in
                    if let error = error {
                    } else if let document = document, document.exists {
                    } else {
                    }
                }
            }
        }
        
        // Test user collection access
        db.collection("users").document(userId).collection("books").getDocuments { snapshot, error in
            if let error = error {
            } else {
            }
        }
        
        // Test Firebase Storage
        testFirebaseStorage(userId: userId)
    }
    
    static func testFirebaseStorage(userId: String) {
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("test/\(userId)/test.txt")
        
        // Create test data
        let testData = "Hello Firebase Storage!".data(using: .utf8)!
        
        // Upload test data
        storageRef.putData(testData, metadata: nil) { metadata, error in
            if let error = error {
            } else {
                
                // Test download
                storageRef.getData(maxSize: 1024) { data, error in
                    if let error = error {
                    } else if let data = data {
                        let content = String(data: data, encoding: .utf8) ?? "unknown"
                    }
                }
            }
        }
    }
}
