import Data.Maybe

data Expr = Number Int |
            Boolean Bool |
            Id String  |
            Prim String |
            Cond Expr Expr Expr |
            App Expr Expr |
            Fun String Expr
          deriving (Eq, Show)

data Type = TInt |
            TBool |
            TFun Type Type |
            TVar String |
            TErr 
          deriving (Eq, Show)

showT :: Type -> String
showT TInt  
  = "Int"
showT TBool 
  = "Bool"
showT (TFun t t') 
  = "(" ++ showT t ++ " -> " ++ showT t' ++ ")"
showT (TVar a) 
  = a
showT TErr  
  = "Type error"

type TypeTable = [(String, Type)]

type TEnv 
  = TypeTable    -- i.e. [(String, Type)]

type Sub 
  = TypeTable    -- i.e. [(String, Type)]  

-- Built-in function types...
primTypes :: TypeTable
primTypes 
  = [("+", TFun TInt (TFun TInt TInt)),
     (">", TFun TInt (TFun TInt TBool)),
     ("==", TFun TInt (TFun TInt TBool)),
     ("not", TFun TBool TBool)]

------------------------------------------------------
-- PART I

-- Pre: The search item is in the table
lookUp :: Eq a => a -> [(a, b)] -> b
lookUp val 
  = snd . head . (dropWhile ((/= val) . fst))   

tryToLookUp :: Eq a => a -> b -> [(a, b)] -> b
tryToLookUp a' b' = lookUp a' . (++[(a', b')]) 

-- Pre: The given value is in the table
reverseLookUp :: Eq b => b -> [(a, b)] -> [a]
reverseLookUp val list = [a | (a,b) <- list, b == val]

occurs :: String -> Type -> Bool
occurs lookFor = occurs'
  where
    occurs' (TFun t1 t2) = (occurs' t1) || (occurs' t2)
    occurs' (TVar str)   = (str == lookFor)
    occurs' _            = False

------------------------------------------------------
-- PART II

-- Pre: There are no user-defined functions (constructor Fun)
-- Pre: All variables in the expression have a binding in the given 
--      type environment
inferType :: Expr -> TEnv -> Type
inferType initialExpr environment = inferType' initialExpr
  where
    inferType' :: Expr -> Type
    inferType' (Number numb)  = TInt
    inferType' (Boolean bool) = TBool
    inferType' (Prim str) = lookUp str primTypes
    inferType' (Id str) = lookUp str environment
    inferType' (Cond exp1 exp2 exp3) 
      | ((inferType' exp1) == TBool) && ((inferType' exp2) == (inferType' exp3)) = inferType' exp2
      | otherwise = TErr
    inferType' (App fun argument) 
      | (TFun from to) <- inferType' fun, (inferType' argument) == from = to
      | otherwise = TErr 
    inferType' (Fun str expr) = inferType' expr

{-
data Expr = Number Int |
            Boolean Bool |
            Id String  |
            Prim String |
            Cond Expr Expr Expr |
            App Expr Expr |
            Fun String Expr
          deriving (Eq, Show)

data Type = TInt |
            TBool |
            TFun Type Type |
            TVar String |
            TErr 
          deriving (Eq, Show)
-}
------------------------------------------------------
-- PART III

applySub :: Sub -> Type -> Type
applySub subList initialType = applySub' initialType
  where
    applySub' :: Type -> Type
    applySub' (TFun type1 type2) 
      | (TFun subt21 subt22) <- subt2, subt1 == subt21 = TFun subt1 subt22
      | otherwise = TFun subt1 subt2
      where
        subt1 = applySub' type1
        subt2 = applySub' type2
    applySub' inputType@(TVar id) = tryToLookUp id inputType subList
    applySub' inputType = inputType


unify :: Type -> Type -> Maybe Sub
unify t t'
  = unifyPairs [(t, t')] []
-- Occurs check and wtf the functions chekc is
unifyPairs :: [(Type, Type)] -> Sub -> Maybe Sub
unifyPairs ((TInt, TInt): typePairs) subList = unifyPairs typePairs subList
unifyPairs ((TBool, TBool): typePairs) subList = unifyPairs typePairs subList
--unifyPairs ((TFun _ _, TVar id2): typePairs) subList = Nothing
--unifyPairs ((TVar id1, TFun _ _): typePairs) subList = Nothing
unifyPairs ((TVar id1, type2): typePairs) subList
  | TVar id2 <- type2, id1 == id2 = unifyPairs typePairs subList
  | occurs id1 type2 = Nothing  
  | otherwise =
    let 
      newSubList = (id1, type2): subList 
      applyNewSub = applySub newSubList
    in 
      unifyPairs (map (\(a, b) -> (applyNewSub a, applyNewSub b)) typePairs) newSubList
unifyPairs ((type1, TVar id2): typePairs) subList  
  | occurs id2 type1 = Nothing
  | otherwise = 
  let 
    newSubList = (id2, type1): subList 
    applyNewSub = applySub newSubList
  in 
    unifyPairs (map (\(a, b) -> (applyNewSub a, applyNewSub b)) typePairs) newSubList
unifyPairs ((TFun type1 type2, TFun type1' type2'): typePairs) subList =  unifyPairs ([(type1, type1'), (type2, type2')] ++ typePairs) subList
unifyPairs [] subList = Just subList
unifyPairs _ _= Nothing
------------------------------------------------------
-- PART IV

updateTEnv :: TEnv -> Sub -> TEnv
updateTEnv tenv tsub
  = map modify tenv
  where
    modify (v, t) = (v, applySub tsub t)

combine :: Sub -> Sub -> Sub
combine sNew sOld
  = sNew ++ updateTEnv sOld sNew

-- In combineSubs [s1, s2,..., sn], s1 should be the *most recent* substitution
-- and will be applied *last*
combineSubs :: [Sub] -> Sub
combineSubs 
  = foldr1 combine

inferPolyType :: Expr -> Type
inferPolyType expr
  = b
  where
    (a, b, c) = inferPolyType' expr [] (map show [0..])
    --(a, b, c) = (flip ((flip inferPolyType') (map show [0..])) []) expr

-- You may optionally wish to use one of the following helper function declarations
-- as suggested in the specification. 
--ex12 = Fun "x" (Fun "y" (App (Id "y") (Id "x")))
inferPolyType' :: Expr -> TEnv -> [String] -> (Sub, Type, [String])
inferPolyType' (Number _) assignments availableNames = (assignments, TInt, availableNames)
inferPolyType' (Prim str) assignments availableNames = (assignments, lookUp str primTypes, availableNames)
inferPolyType' (Id str) assignments availableNames = (assignments, lookUp str assignments, availableNames)
inferPolyType' (Boolean _) assignments availableNames = (assignments, TBool, availableNames)
inferPolyType' (Fun x e) assignments (name: names) 
  | te == TErr = (assignments', TErr, availableNames')
  | otherwise = (assignments',applySub assignments' (TFun ( xTempType) te), availableNames')
  where
    xTempType = TVar ("a" ++ name)
    newAssignments = (x, xTempType) : assignments
    (assignments', te, availableNames') = inferPolyType' e newAssignments names 
inferPolyType' (App fun argument) assignments availableNames
--possible terr check needed
  | (TFun startType endType) <- funType, startType == argType = (assignments'', endType, names'')
  | (TFun startType endType) <- funType, (Just subList) <- (unify (applySub assignments'' startType) (applySub assignments argType)) = ((subList ++ assignments''), (TFun (applySub subList startType) (applySub subList endType)),  names'')
  | (Just subList) <- (unify funType argType) = ((subList ++ assignments''), (TFun (applySub subList funType) (applySub subList argType)),  names'')
  |  otherwise = (assignments'', TErr, names'')
    where 
      (assignments', funType, names') = inferPolyType' fun assignments availableNames 
      (assignments'', argType, names'') = inferPolyType' argument assignments' names'
inferPolyType' currentExpression assignments availableNames = undefined
-- inferPolyType' :: Expr -> TEnv -> Int -> (Sub, Type, Int)
-- inferPolyType' 
--   = undefined

------------------------------------------------------
-- Monomorphic type inference test cases from Table 1...

env :: TEnv
env = [("x",TInt),("y",TInt),("b",TBool),("c",TBool)]

ex1, ex2, ex3, ex4, ex5, ex6, ex7, ex8 :: Expr
type1, type2, type3, type4, type5, type6, type7, type8 :: Type

ex1 = Number 9
type1 = TInt

ex2 = Boolean False
type2 = TBool

ex3 = Prim "not"
type3 =  TFun TBool TBool

ex4 = App (Prim "not") (Boolean True)
type4 = TBool

ex5 = App (Prim ">") (Number 0)
type5 = TFun TInt TBool

ex6 = App (App (Prim "+") (Boolean True)) (Number 5)
type6 = TErr

ex7 = Cond (Boolean True) (Boolean False) (Id "c")
type7 = TBool

ex8 = Cond (App (Prim "==") (Number 4)) (Id "b") (Id "c")
type8 = TErr

------------------------------------------------------
-- Unification test cases from Table 2...

u1a, u1b, u2a, u2b, u3a, u3b, u4a, u4b, u5a, u5b, u6a, u6b :: Type
sub1, sub2, sub3, sub4, sub5, sub6 :: Maybe Sub

u1a = TFun (TVar "a") TInt
u1b = TVar "b"
sub1 = Just [("b",TFun (TVar "a") TInt)]

u2a = TFun TBool TBool
u2b = TFun TBool TBool
sub2 = Just []

u3a = TFun (TVar "a") TInt
u3b = TFun TBool TInt
sub3 = Just [("a",TBool)]

u4a = TBool
u4b = TFun TInt TBool
sub4 = Nothing

u5a = TFun (TVar "a") TInt
u5b = TFun TBool (TVar "b")
sub5 = Just [("b",TInt),("a",TBool)]

u6a = TFun (TVar "a") (TVar "a")
u6b = TVar "a"
sub6 = Nothing

------------------------------------------------------
-- Polymorphic type inference test cases from Table 3...

ex9, ex10, ex11, ex12, ex13, ex14 :: Expr
type9, type10, type11, type12, type13, type14 :: Type

ex9 = Fun "x" (Boolean True)
type9 = TFun (TVar "a1") TBool

ex10 = Fun "x" (Id "x")
type10 = TFun (TVar "a1") (TVar "a1")

ex11 = Fun "x" (App (Prim "not") (Id "x"))
type11 = TFun TBool TBool

ex12 = Fun "x" (Fun "y" (App (Id "y") (Id "x")))
type12 = TFun (TVar "a1") (TFun (TFun (TVar "a1") (TVar "a3")) (TVar "a3"))

ex13 = Fun "x" (Fun "y" (App (App (Id "y") (Id "x")) (Number 7)))
type13 = TFun (TVar "a1") (TFun (TFun (TVar "a1") (TFun TInt (TVar "a3"))) 
              (TVar "a3"))

ex14 = Fun "x" (Fun "y" (App (Id "x") (Prim "+"))) 
type14 = TFun (TFun (TFun TInt (TFun TInt TInt)) (TVar "a3")) 
              (TFun (TVar "a2") (TVar "a3"))
