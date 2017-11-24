//
//  ViewController.swift
//  msrmedia
//
//  Created by Jeffrey Berthiaume on 9/11/15.
//  Copyright © 2015 Amherst, Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  
  @IBOutlet weak var collectionView: UICollectionView!
  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  var thumbnails:[String?]? = nil
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
    thumbnails = self.pathsForAllImages()
  }
  
  @IBAction func takePhoto () {
    self.performSegue(withIdentifier: "segueCapturePhoto", sender: nil)
  }
  
  
  @IBAction func recordVideo (_ sender: UIButton) {
    self.performSegue(withIdentifier: "segueRecordVideo", sender: nil)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "segueCapturePhoto" {
      let vc = segue.destination as! CapturePhotoViewController
      vc.delegate = self
    }
  }
  
  func pathsForAllImages () -> [String?]? {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var array:[String?]? = nil
    
    let properties = [URLResourceKey.localizedNameKey, URLResourceKey.creationDateKey, URLResourceKey.localizedTypeDescriptionKey]
    
    print (url);
    
    do {
      let directoryUrls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: properties, options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
      array = directoryUrls.map(){ $0.lastPathComponent }.filter(){ ($0! as NSString).pathExtension == "jpg" }
      if array?.count == 0 {
        array = nil
      }
    }
    catch let error as NSError {
      print(error.description)
    }
    return array
    
  }
  
}

extension ViewController: CapturePhotoDelegate {
  
  func didTakePhoto(_ img: UIImage) {
    self.dismiss(animated: true, completion: { })
    
    let destinationPath = documentsURL.appendingPathComponent(UUID().uuidString + ".jpg").path
    try? UIImageJPEGRepresentation(img, 1.0)!.write(to: URL(fileURLWithPath: destinationPath), options: [.atomic])
    
    thumbnails = self.pathsForAllImages()
    collectionView.reloadData()
  }
  
}

extension ViewController: UICollectionViewDataSource {
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if let images = thumbnails {
      return images.count
    } else {
      return 0
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CellThumbnail", for: indexPath) as! ThumbnailCell
    // Configure the cell
    if let files = thumbnails {
      cell.thumbnail.image = UIImage(contentsOfFile: documentsURL.appendingPathComponent(files[indexPath.row]!).path)
    }
    
    return cell
  }
  
}
