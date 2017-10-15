//
//  CollectionViewController.swift
//  Nametag
//
//  Created by Nate Thompson on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

class CollectionViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noItemsLabel: UILabel!
    
    @IBAction func swipeGestureRecognizer(_ sender: UISwipeGestureRecognizer) {
        performDismissalAnimation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        preflightPresentationAnimation()
        view.backgroundColor = .clear
        noItemsLabel.isHidden = true
    }
    
    func preflightPresentationAnimation() {
        collectionView.transform = CGAffineTransform(translationX: view.frame.width, y: 0)
        noItemsLabel.transform = CGAffineTransform(translationX: view.frame.width + 100, y: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performPresentationAnimation()
    }
    
    func performPresentationAnimation() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.87,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.collectionView.transform = .identity
                self.noItemsLabel.transform = .identity
        },
            completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        performDismissalAnimation()
    }
    
    func performDismissalAnimation() {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.87,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.collectionView.transform = CGAffineTransform(translationX: self.view.frame.width, y: 0)
                self.noItemsLabel.transform = CGAffineTransform(translationX: self.view.frame.width + 100, y: 0)
        },
            completion: { _ in
                self.dismiss(animated: false, completion: nil)
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self

        collectionView.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 15, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        noItemsLabel.isHidden = NTFaceDatabase.faces.count != 0
        return NTFaceDatabase.faces.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "face", for: indexPath) as! FaceCell
        
        cell.decorate(for: NTFaceDatabase.faces[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let name = NTFaceDatabase.faces[indexPath.item].name
        
        let alert = UIAlertController(
            title: "Edit \(name)",
            message: "Delete \(name) or edit the name.",
            preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Edit Name", style: UIAlertActionStyle.default, handler: { _ in
            let editor = UIAlertController(
                title: "Edit Name",
                message: "Edit the name that belongs to this face.",
                preferredStyle: UIAlertControllerStyle.alert)
            editor.addTextField(configurationHandler: { textField in
                textField.text = name
            })
            editor.addAction(UIAlertAction(title: "Done", style: UIAlertActionStyle.default, handler: { _ in
                NTFaceDatabase.faces[indexPath.item].name = (editor.textFields?.first?.text)!
                NTFaceDatabase.save()
                collectionView.reloadData()
            }))
            editor.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(editor, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { _ in
            NTFaceDatabase.removeFace(NTFaceDatabase.faces[indexPath.item])
            collectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

class FaceCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var vectorsLabel: UILabel!
    
    func decorate(for face: Face) {
        imageView.image = face.image
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.frame.height/2
        
        nameLabel.text = face.name
    }
}
