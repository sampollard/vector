{-# LANGUAGE BangPatterns, MultiParamTypeClasses, TypeFamilies, FlexibleContexts, FlexibleInstances #-}
#if __GLASGOW_HASKELL__ >= 707
{-# LANGUAGE DeriveDataTypeable, StandaloneDeriving #-}
#endif
{-# OPTIONS_HADDOCK hide #-}

#include "MachDeps.h"

-- |
-- Module      : Data.Vector.Unboxed.Base
-- Copyright   : (c) Roman Leshchinskiy 2009-2010
-- License     : BSD-style
--
-- Maintainer  : Roman Leshchinskiy <rl@cse.unsw.edu.au>
-- Stability   : experimental
-- Portability : non-portable
--
-- Adaptive unboxed vectors: basic implementation
--

module Data.Vector.Unboxed.Base (
  MVector(..), IOVector, STVector, Vector(..), Unbox
) where

import qualified Data.Vector.Generic         as G
import qualified Data.Vector.Generic.Mutable as M

import qualified Data.Vector.Primitive as P

import Control.DeepSeq ( NFData(rnf) )

import Control.Monad.Primitive
import Control.Monad ( liftM )

#if defined(__GLASGOW_HASKELL_LLVM__)
import Data.Primitive.Multi
import Foreign ( sizeOf )
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */

import Data.Word ( Word, Word8, Word16, Word32, Word64 )
import Data.Int  ( Int8, Int16, Int32, Int64 )
import Data.Complex

#if __GLASGOW_HASKELL__ >= 707
import Data.Typeable ( Typeable )
#else
import Data.Typeable ( Typeable1(..), Typeable2(..), mkTyConApp,
#if MIN_VERSION_base(4,4,0)
                       mkTyCon3
#else
                       mkTyCon
#endif
                     )
#endif

import Data.Data     ( Data(..) )

#include "vector.h"

data family MVector s a
data family Vector    a

type IOVector = MVector RealWorld
type STVector s = MVector s

type instance G.Mutable Vector = MVector

class (G.Vector Vector a, M.MVector MVector a) => Unbox a

instance NFData (Vector a) where rnf !_ = ()
instance NFData (MVector s a) where rnf !_ = ()

-- -----------------
-- Data and Typeable
-- -----------------
#if __GLASGOW_HASKELL__ >= 707
deriving instance Typeable Vector
deriving instance Typeable MVector
#else
#if MIN_VERSION_base(4,4,0)
vectorTyCon = mkTyCon3 "vector"
#else
vectorTyCon m s = mkTyCon $ m ++ "." ++ s
#endif

instance Typeable1 Vector where
  typeOf1 _ = mkTyConApp (vectorTyCon "Data.Vector.Unboxed" "Vector") []

instance Typeable2 MVector where
  typeOf2 _ = mkTyConApp (vectorTyCon "Data.Vector.Unboxed.Mutable" "MVector") []
#endif

instance (Data a, Unbox a) => Data (Vector a) where
  gfoldl       = G.gfoldl
  toConstr _   = error "toConstr"
  gunfold _ _  = error "gunfold"
  dataTypeOf _ = G.mkType "Data.Vector.Unboxed.Vector"
  dataCast1    = G.dataCast

-- ----
-- Unit
-- ----

newtype instance MVector s () = MV_Unit Int
newtype instance Vector    () = V_Unit Int

instance Unbox ()

instance M.MVector MVector () where
  {-# INLINE basicLength #-}
  {-# INLINE basicUnsafeSlice #-}
  {-# INLINE basicOverlaps #-}
  {-# INLINE basicUnsafeNew #-}
  {-# INLINE basicUnsafeRead #-}
  {-# INLINE basicUnsafeWrite #-}
  {-# INLINE basicClear #-}
  {-# INLINE basicSet #-}
  {-# INLINE basicUnsafeCopy #-}
  {-# INLINE basicUnsafeGrow #-}

  basicLength (MV_Unit n) = n

  basicUnsafeSlice i m (MV_Unit n) = MV_Unit m

  basicOverlaps _ _ = False

  basicUnsafeNew n = return (MV_Unit n)

  basicUnsafeRead (MV_Unit _) _ = return ()

  basicUnsafeWrite (MV_Unit _) _ () = return ()

  basicClear _ = return ()

  basicSet (MV_Unit _) () = return ()

  basicUnsafeCopy (MV_Unit _) (MV_Unit _) = return ()

  basicUnsafeGrow (MV_Unit n) m = return $ MV_Unit (n+m)

instance G.Vector Vector () where
  {-# INLINE basicUnsafeFreeze #-}
  basicUnsafeFreeze (MV_Unit n) = return $ V_Unit n

  {-# INLINE basicUnsafeThaw #-}
  basicUnsafeThaw (V_Unit n) = return $ MV_Unit n

  {-# INLINE basicLength #-}
  basicLength (V_Unit n) = n

  {-# INLINE basicUnsafeSlice #-}
  basicUnsafeSlice i m (V_Unit n) = V_Unit m

  {-# INLINE basicUnsafeIndexM #-}
  basicUnsafeIndexM (V_Unit _) i = return ()

  {-# INLINE basicUnsafeCopy #-}
  basicUnsafeCopy (MV_Unit _) (V_Unit _) = return ()

  {-# INLINE elemseq #-}
  elemseq _ = seq


-- ---------------
-- Primitive types
-- ---------------

#define primMVector(ty,con)                                             \
instance M.MVector MVector ty where {                                   \
  {-# INLINE basicLength #-}                                            \
; {-# INLINE basicUnsafeSlice #-}                                       \
; {-# INLINE basicOverlaps #-}                                          \
; {-# INLINE basicUnsafeNew #-}                                         \
; {-# INLINE basicUnsafeReplicate #-}                                   \
; {-# INLINE basicUnsafeRead #-}                                        \
; {-# INLINE basicUnsafeWrite #-}                                       \
; {-# INLINE basicClear #-}                                             \
; {-# INLINE basicSet #-}                                               \
; {-# INLINE basicUnsafeCopy #-}                                        \
; {-# INLINE basicUnsafeGrow #-}                                        \
; basicLength (con v) = M.basicLength v                                 \
; basicUnsafeSlice i n (con v) = con $ M.basicUnsafeSlice i n v         \
; basicOverlaps (con v1) (con v2) = M.basicOverlaps v1 v2               \
; basicUnsafeNew n = con `liftM` M.basicUnsafeNew n                     \
; basicUnsafeReplicate n x = con `liftM` M.basicUnsafeReplicate n x     \
; basicUnsafeRead (con v) i = M.basicUnsafeRead v i                     \
; basicUnsafeWrite (con v) i x = M.basicUnsafeWrite v i x               \
; basicClear (con v) = M.basicClear v                                   \
; basicSet (con v) x = M.basicSet v x                                   \
; basicUnsafeCopy (con v1) (con v2) = M.basicUnsafeCopy v1 v2           \
; basicUnsafeMove (con v1) (con v2) = M.basicUnsafeMove v1 v2           \
; basicUnsafeGrow (con v) n = con `liftM` M.basicUnsafeGrow v n }

#define primVector(ty,con,mcon)                                         \
instance G.Vector Vector ty where {                                     \
  {-# INLINE basicUnsafeFreeze #-}                                      \
; {-# INLINE basicUnsafeThaw #-}                                        \
; {-# INLINE basicLength #-}                                            \
; {-# INLINE basicUnsafeSlice #-}                                       \
; {-# INLINE basicUnsafeIndexM #-}                                      \
; {-# INLINE elemseq #-}                                                \
; basicUnsafeFreeze (mcon v) = con `liftM` G.basicUnsafeFreeze v        \
; basicUnsafeThaw (con v) = mcon `liftM` G.basicUnsafeThaw v            \
; basicLength (con v) = G.basicLength v                                 \
; basicUnsafeSlice i n (con v) = con $ G.basicUnsafeSlice i n v         \
; basicUnsafeIndexM (con v) i = G.basicUnsafeIndexM v i                 \
; basicUnsafeCopy (mcon mv) (con v) = G.basicUnsafeCopy mv v            \
; elemseq _ = seq }

#define primPackedMVector(ty,con)                                       \
instance M.PackedMVector MVector ty where {                             \
  {-# INLINE basicUnsafeReadAsMulti #-}                                 \
; {-# INLINE basicUnsafeWriteAsMulti #-}                                \
; basicUnsafeReadAsMulti (con (P.MVector i _ arr)) j =                  \
      readByteArrayAsMulti arr (i+j)                                    \
; basicUnsafeWriteAsMulti (con (P.MVector i _ arr)) j x =               \
      writeByteArrayAsMulti arr (i+j) x }

#define primPackedVector(ty,con)                                        \
instance G.PackedVector Vector ty where {                               \
  {-# INLINE basicUnsafeIndexAsMultiM #-}                               \
; basicUnsafeIndexAsMultiM (con (P.Vector i _ arr)) j =                 \
      return $! indexByteArrayAsMulti arr (i+j)                         \
; {-# INLINE basicUnsafePrefetchDataM #-}                               \
; basicUnsafePrefetchDataM (con (P.Vector i n arr)) j k =               \
      do { arr' <- return $! prefetchByteArrayData arr ((i+j)*sizeOf (undefined::ty)+k)  \
         ; return (con (P.Vector i n arr')) }}

newtype instance MVector s Int = MV_Int (P.MVector s Int)
newtype instance Vector    Int = V_Int  (P.Vector    Int)
instance Unbox Int
primMVector(Int, MV_Int)
primVector(Int, V_Int, MV_Int)
#if defined(__GLASGOW_HASKELL_LLVM__)
#if WORD_SIZE_IN_BITS == 32 || WORD_SIZE_IN_BITS == 64
primPackedMVector(Int, MV_Int)
primPackedVector(Int, V_Int)
#endif
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */

newtype instance MVector s Int8 = MV_Int8 (P.MVector s Int8)
newtype instance Vector    Int8 = V_Int8  (P.Vector    Int8)
instance Unbox Int8
primMVector(Int8, MV_Int8)
primVector(Int8, V_Int8, MV_Int8)

newtype instance MVector s Int16 = MV_Int16 (P.MVector s Int16)
newtype instance Vector    Int16 = V_Int16  (P.Vector    Int16)
instance Unbox Int16
primMVector(Int16, MV_Int16)
primVector(Int16, V_Int16, MV_Int16)

newtype instance MVector s Int32 = MV_Int32 (P.MVector s Int32)
newtype instance Vector    Int32 = V_Int32  (P.Vector    Int32)
instance Unbox Int32
primMVector(Int32, MV_Int32)
primVector(Int32, V_Int32, MV_Int32)
#if defined(__GLASGOW_HASKELL_LLVM__)
primPackedMVector(Int32, MV_Int32)
primPackedVector(Int32, V_Int32)
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */

newtype instance MVector s Int64 = MV_Int64 (P.MVector s Int64)
newtype instance Vector    Int64 = V_Int64  (P.Vector    Int64)
instance Unbox Int64
primMVector(Int64, MV_Int64)
primVector(Int64, V_Int64, MV_Int64)
#if defined(__GLASGOW_HASKELL_LLVM__)
primPackedMVector(Int64, MV_Int64)
primPackedVector(Int64, V_Int64)
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */


newtype instance MVector s Word = MV_Word (P.MVector s Word)
newtype instance Vector    Word = V_Word  (P.Vector    Word)
instance Unbox Word
primMVector(Word, MV_Word)
primVector(Word, V_Word, MV_Word)

newtype instance MVector s Word8 = MV_Word8 (P.MVector s Word8)
newtype instance Vector    Word8 = V_Word8  (P.Vector    Word8)
instance Unbox Word8
primMVector(Word8, MV_Word8)
primVector(Word8, V_Word8, MV_Word8)

newtype instance MVector s Word16 = MV_Word16 (P.MVector s Word16)
newtype instance Vector    Word16 = V_Word16  (P.Vector    Word16)
instance Unbox Word16
primMVector(Word16, MV_Word16)
primVector(Word16, V_Word16, MV_Word16)

newtype instance MVector s Word32 = MV_Word32 (P.MVector s Word32)
newtype instance Vector    Word32 = V_Word32  (P.Vector    Word32)
instance Unbox Word32
primMVector(Word32, MV_Word32)
primVector(Word32, V_Word32, MV_Word32)

newtype instance MVector s Word64 = MV_Word64 (P.MVector s Word64)
newtype instance Vector    Word64 = V_Word64  (P.Vector    Word64)
instance Unbox Word64
primMVector(Word64, MV_Word64)
primVector(Word64, V_Word64, MV_Word64)


newtype instance MVector s Float = MV_Float (P.MVector s Float)
newtype instance Vector    Float = V_Float  (P.Vector    Float)
instance Unbox Float
primMVector(Float, MV_Float)
primVector(Float, V_Float, MV_Float)
#if defined(__GLASGOW_HASKELL_LLVM__)
primPackedMVector(Float, MV_Float)
primPackedVector(Float, V_Float)
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */

newtype instance MVector s Double = MV_Double (P.MVector s Double)
newtype instance Vector    Double = V_Double  (P.Vector    Double)
instance Unbox Double
primMVector(Double, MV_Double)
primVector(Double, V_Double, MV_Double)
#if defined(__GLASGOW_HASKELL_LLVM__)
primPackedMVector(Double, MV_Double)
primPackedVector(Double, V_Double)
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */


newtype instance MVector s Char = MV_Char (P.MVector s Char)
newtype instance Vector    Char = V_Char  (P.Vector    Char)
instance Unbox Char
primMVector(Char, MV_Char)
primVector(Char, V_Char, MV_Char)

-- ----
-- Bool
-- ----

fromBool :: Bool -> Word8
{-# INLINE fromBool #-}
fromBool True = 1
fromBool False = 0

toBool :: Word8 -> Bool
{-# INLINE toBool #-}
toBool 0 = False
toBool _ = True

newtype instance MVector s Bool = MV_Bool (P.MVector s Word8)
newtype instance Vector    Bool = V_Bool  (P.Vector    Word8)

instance Unbox Bool

instance M.MVector MVector Bool where
  {-# INLINE basicLength #-}
  {-# INLINE basicUnsafeSlice #-}
  {-# INLINE basicOverlaps #-}
  {-# INLINE basicUnsafeNew #-}
  {-# INLINE basicUnsafeReplicate #-}
  {-# INLINE basicUnsafeRead #-}
  {-# INLINE basicUnsafeWrite #-}
  {-# INLINE basicClear #-}
  {-# INLINE basicSet #-}
  {-# INLINE basicUnsafeCopy #-}
  {-# INLINE basicUnsafeGrow #-}
  basicLength (MV_Bool v) = M.basicLength v
  basicUnsafeSlice i n (MV_Bool v) = MV_Bool $ M.basicUnsafeSlice i n v
  basicOverlaps (MV_Bool v1) (MV_Bool v2) = M.basicOverlaps v1 v2
  basicUnsafeNew n = MV_Bool `liftM` M.basicUnsafeNew n
  basicUnsafeReplicate n x = MV_Bool `liftM` M.basicUnsafeReplicate n (fromBool x)
  basicUnsafeRead (MV_Bool v) i = toBool `liftM` M.basicUnsafeRead v i
  basicUnsafeWrite (MV_Bool v) i x = M.basicUnsafeWrite v i (fromBool x)
  basicClear (MV_Bool v) = M.basicClear v
  basicSet (MV_Bool v) x = M.basicSet v (fromBool x)
  basicUnsafeCopy (MV_Bool v1) (MV_Bool v2) = M.basicUnsafeCopy v1 v2
  basicUnsafeMove (MV_Bool v1) (MV_Bool v2) = M.basicUnsafeMove v1 v2
  basicUnsafeGrow (MV_Bool v) n = MV_Bool `liftM` M.basicUnsafeGrow v n

instance G.Vector Vector Bool where
  {-# INLINE basicUnsafeFreeze #-}
  {-# INLINE basicUnsafeThaw #-}
  {-# INLINE basicLength #-}
  {-# INLINE basicUnsafeSlice #-}
  {-# INLINE basicUnsafeIndexM #-}
  {-# INLINE elemseq #-}
  basicUnsafeFreeze (MV_Bool v) = V_Bool `liftM` G.basicUnsafeFreeze v
  basicUnsafeThaw (V_Bool v) = MV_Bool `liftM` G.basicUnsafeThaw v
  basicLength (V_Bool v) = G.basicLength v
  basicUnsafeSlice i n (V_Bool v) = V_Bool $ G.basicUnsafeSlice i n v
  basicUnsafeIndexM (V_Bool v) i = toBool `liftM` G.basicUnsafeIndexM v i
  basicUnsafeCopy (MV_Bool mv) (V_Bool v) = G.basicUnsafeCopy mv v
  elemseq _ = seq

-- -------
-- Complex
-- -------

newtype instance MVector s (Complex a) = MV_Complex (MVector s (a,a))
newtype instance Vector    (Complex a) = V_Complex  (Vector    (a,a))

instance (RealFloat a, Unbox a) => Unbox (Complex a)

instance (RealFloat a, Unbox a) => M.MVector MVector (Complex a) where
  {-# INLINE basicLength #-}
  {-# INLINE basicUnsafeSlice #-}
  {-# INLINE basicOverlaps #-}
  {-# INLINE basicUnsafeNew #-}
  {-# INLINE basicUnsafeReplicate #-}
  {-# INLINE basicUnsafeRead #-}
  {-# INLINE basicUnsafeWrite #-}
  {-# INLINE basicClear #-}
  {-# INLINE basicSet #-}
  {-# INLINE basicUnsafeCopy #-}
  {-# INLINE basicUnsafeGrow #-}
  basicLength (MV_Complex v) = M.basicLength v
  basicUnsafeSlice i n (MV_Complex v) = MV_Complex $ M.basicUnsafeSlice i n v
  basicOverlaps (MV_Complex v1) (MV_Complex v2) = M.basicOverlaps v1 v2
  basicUnsafeNew n = MV_Complex `liftM` M.basicUnsafeNew n
  basicUnsafeReplicate n (x :+ y) = MV_Complex `liftM` M.basicUnsafeReplicate n (x,y)
  basicUnsafeRead (MV_Complex v) i = uncurry (:+) `liftM` M.basicUnsafeRead v i
  basicUnsafeWrite (MV_Complex v) i (x :+ y) = M.basicUnsafeWrite v i (x,y)
  basicClear (MV_Complex v) = M.basicClear v
  basicSet (MV_Complex v) (x :+ y) = M.basicSet v (x,y)
  basicUnsafeCopy (MV_Complex v1) (MV_Complex v2) = M.basicUnsafeCopy v1 v2
  basicUnsafeMove (MV_Complex v1) (MV_Complex v2) = M.basicUnsafeMove v1 v2
  basicUnsafeGrow (MV_Complex v) n = MV_Complex `liftM` M.basicUnsafeGrow v n

instance (RealFloat a, Unbox a) => G.Vector Vector (Complex a) where
  {-# INLINE basicUnsafeFreeze #-}
  {-# INLINE basicUnsafeThaw #-}
  {-# INLINE basicLength #-}
  {-# INLINE basicUnsafeSlice #-}
  {-# INLINE basicUnsafeIndexM #-}
  {-# INLINE elemseq #-}
  basicUnsafeFreeze (MV_Complex v) = V_Complex `liftM` G.basicUnsafeFreeze v
  basicUnsafeThaw (V_Complex v) = MV_Complex `liftM` G.basicUnsafeThaw v
  basicLength (V_Complex v) = G.basicLength v
  basicUnsafeSlice i n (V_Complex v) = V_Complex $ G.basicUnsafeSlice i n v
  basicUnsafeIndexM (V_Complex v) i
                = uncurry (:+) `liftM` G.basicUnsafeIndexM v i
  basicUnsafeCopy (MV_Complex mv) (V_Complex v)
                = G.basicUnsafeCopy mv v
  elemseq _ (x :+ y) z = G.elemseq (undefined :: Vector a) x
                       $ G.elemseq (undefined :: Vector a) y z

-- ------
-- Tuples
-- ------

#define DEFINE_INSTANCES
#include "unbox-tuple-instances"

#if defined(__GLASGOW_HASKELL_LLVM__)
instance (Unbox a, M.PackedMVector MVector a) => M.PackedMVector MVector (a, a) where
  {-# INLINE basicUnsafeReadAsMulti #-}
  {-# INLINE basicUnsafeWriteAsMulti #-}
  basicUnsafeReadAsMulti (MV_2 _ v1 v2) j =
      do  x <- M.basicUnsafeReadAsMulti v1 j
          y <- M.basicUnsafeReadAsMulti v2 j
          return $ M_2 x y

  basicUnsafeWriteAsMulti (MV_2 _ v1 v2) j (M_2 x y) =
      do  M.basicUnsafeWriteAsMulti v1 j x
          M.basicUnsafeWriteAsMulti v2 j y

instance (Unbox a, G.PackedVector Vector a) => G.PackedVector Vector (a, a) where
  {-# INLINE basicUnsafeIndexAsMultiM #-}
  basicUnsafeIndexAsMultiM (V_2 _ v1 v2) j =
      do  x <- G.basicUnsafeIndexAsMultiM v1 j
          y <- G.basicUnsafeIndexAsMultiM v2 j
          return $! M_2 x y

  basicUnsafePrefetchDataM (V_2 n v1 v2) j k =
      do  v1' <- G.basicUnsafePrefetchDataM v1 j k
          v2' <- G.basicUnsafePrefetchDataM v2 j k
          return $! V_2 n v1' v2'

instance (Unbox a, M.PackedMVector MVector a) => M.PackedMVector MVector (a, a, a) where
  {-# INLINE basicUnsafeReadAsMulti #-}
  {-# INLINE basicUnsafeWriteAsMulti #-}
  basicUnsafeReadAsMulti (MV_3 _ v1 v2 v3) j =
      do  x <- M.basicUnsafeReadAsMulti v1 j
          y <- M.basicUnsafeReadAsMulti v2 j
          z <- M.basicUnsafeReadAsMulti v3 j
          return $ M_3 x y z

  basicUnsafeWriteAsMulti (MV_3 _ v1 v2 v3) j (M_3 x y z) =
      do  M.basicUnsafeWriteAsMulti v1 j x
          M.basicUnsafeWriteAsMulti v2 j y
          M.basicUnsafeWriteAsMulti v3 j z

instance (Unbox a, G.PackedVector Vector a) => G.PackedVector Vector (a, a, a) where
  {-# INLINE basicUnsafeIndexAsMultiM #-}
  basicUnsafeIndexAsMultiM (V_3 _ v1 v2 v3) j =
      do  x <- G.basicUnsafeIndexAsMultiM v1 j
          y <- G.basicUnsafeIndexAsMultiM v2 j
          z <- G.basicUnsafeIndexAsMultiM v3 j
          return $! M_3 x y z

  basicUnsafePrefetchDataM (V_3 n v1 v2 v3) j k =
      do  v1' <- G.basicUnsafePrefetchDataM v1 j k
          v2' <- G.basicUnsafePrefetchDataM v2 j k
          v3' <- G.basicUnsafePrefetchDataM v3 j k
          return $! V_3 n v1' v2' v3'
#endif /* defined(__GLASGOW_HASKELL_LLVM__) */
