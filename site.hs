{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Hakyll

main :: IO ()
main = hakyll $ do
  -- Root-level static assets (e.g. CNAME) are copied to the site root.
  match "static/*" $ do
    route (gsubRoute "static/" (const ""))
    compile copyFileCompiler

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match "templates/*" $
    compile templateBodyCompiler

  -- Landing page.
  match "content/index.md" $ do
    route (constRoute "index.html")
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls

  -- Documentation pages: content/docs/foo.md -> docs/foo.html
  match "content/docs/*.md" $ do
    route (gsubRoute "content/" (const "") `composeRoutes` setExtension "html")
    compile $
      pandocCompiler
        >>= loadAndApplyTemplate "templates/default.html" defaultContext
        >>= relativizeUrls
