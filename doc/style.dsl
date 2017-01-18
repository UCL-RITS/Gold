<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
    <!ENTITY html-ss
      PUBLIC "-//Norman Walsh//DOCUMENT DocBook HTML Stylesheet//EN" CDATA dsssl>
    <!ENTITY print-ss
      PUBLIC "-//Norman Walsh//DOCUMENT DocBook Print Stylesheet//EN" CDATA dsssl>
    ]>
    
    <style-sheet>
    <style-specification id="print" use="print-stylesheet">
    <style-specification-body> 
    
    ;; Allow mediaobject at top of title page
    (define (article-titlepage-recto-elements)
      (list 
        (normalize "mediaobject")
        (normalize "title")
        (normalize "subtitle")
        (normalize "corpauthor")
        (normalize "authorgroup")
        (normalize "author")
        (normalize "releaseinfo")
        (normalize "copyright")
        (normalize "pubdate")
        (normalize "revhistory")
        (normalize "abstract")))

    ;; Allow mediaobject at top of title page
    (define (book-titlepage-recto-elements)
      (list 
        (normalize "mediaobject")
        (normalize "title")
        (normalize "releaseinfo")
        (normalize "subtitle")
        (normalize "corpauthor")
        (normalize "copyright")
        (normalize "pubdate")
        (normalize "revhistory")
        (normalize "abstract")))

    ;; Center images
    (element imagedata
      (if (have-ancestor? (normalize "mediaobject"))
        ($img$ (current-node) #t)                 
        ($img$ (current-node) #f)))
    
    (define %generate-article-toc% #t)
    (define %generate-article-titlepage-on-separate-page% #t)

    </style-specification-body>
    </style-specification>
    <style-specification id="html" use="html-stylesheet">
    <style-specification-body> 
    
    ;; Allow mediaobject at top of title page
    (define (article-titlepage-recto-elements)
      (list 
        (normalize "mediaobject")
        (normalize "title")
        (normalize "subtitle")
        (normalize "corpauthor")
        (normalize "authorgroup")
        (normalize "author")
        (normalize "releaseinfo")
        (normalize "copyright")
        (normalize "pubdate")
        (normalize "revhistory")
        (normalize "abstract")))

    (define %generate-article-toc% #t)
    (define %generate-article-titlepage-on-separate-page% #t)
    
    </style-specification-body>
    </style-specification>
    <external-specification id="print-stylesheet" document="print-ss">
    <external-specification id="html-stylesheet" document="html-ss">
    </style-sheet>
