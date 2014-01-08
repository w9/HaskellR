-- |
-- Copyright: (C) 2013 Amgen, Inc.

{-# Language GADTs #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# Language ViewPatterns #-}

module H.Prelude
  ( module Data.IORef
  , module Language.R.Instance
  , module Foreign.R.Error
  , print
  , module Control.Monad.R.Class
  -- * R Value
  , module H.Prelude.RVal
  -- * Language.R functions
  , module H.Prelude.Reexports
  -- * Literals
  , module Language.R.Literal
  -- * Globals
  , module Language.R.Globals
  , withProtected
  ) where


import           Control.Monad.R.Class
import           H.Internal.Prelude
import qualified Foreign.R as R
import Language.R.HExp
import Language.R (r1)
import qualified Data.Vector.SEXP as Vector

-- Reexported modules.
import           H.Prelude.Reexports
import           Language.R.Globals
import           H.Prelude.RVal
import           Language.R.Literal
import Language.R.Instance
import qualified Language.R ( withProtected )
import Foreign.R.Error

import Control.Monad.Catch
import qualified Data.Text.Lazy.IO as Text
import qualified Data.Text as Text
import qualified Data.Text.Lazy as Text.Lazy
import Data.Text.Lazy (Text)

import Control.Applicative ((<$>))
import Control.Monad ((>=>))
import Data.IORef
import Foreign.C (withCString)
import System.IO.Unsafe (unsafePerformIO)

import Prelude hiding (Show(..), print)
import qualified Prelude

class Show a where
  -- | Equivalent of R's @deparse()@.
  show :: a -> Text

  -- | Make this a class method to allow matching R's @print()@ behaviour, whose
  -- output is subtly different from @deparse()@.
  print :: MonadR m => a -> m ()
  print = io . Text.putStrLn . show

instance Show (SEXP a) where
  show s = unsafePerformIO $ Language.R.withProtected (return s) $ \_ ->
           withCString "quote" $ R.install >=> \quote ->
           (r1 "deparse" <$> R.lang2 quote s) >>= \(SomeSEXP slang) ->
           return .
           Text.Lazy.fromChunks .
           map (Text.pack . Vector.toString . vector) .
           Vector.toList .
           vector $
           (R.unsafeCoerce slang :: SEXP R.String)

  print e = io $ Language.R.withProtected (return e) R.printValue

instance Show R.SomeSEXP where
  show s = R.unSomeSEXP s show
  print s = R.unSomeSEXP s print

withProtected :: (MonadR m, MonadCatch m) => m (SEXP a) -> ((SEXP a) -> m b) -> m b
withProtected accure =
    bracket (accure >>= \x -> io $ R.protect x >> return x)
            (const (io $ R.unprotect 1))
