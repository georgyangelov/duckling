-- Copyright (c) 2016-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree.


{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}

module Duckling.Duration.BG.Rules
  ( rules
  ) where

import Data.Semigroup ((<>))
import Data.String
import Data.Text (Text)
import Prelude
import qualified Data.Text as Text

import Duckling.Dimensions.Types
import Duckling.Duration.Helpers
import Duckling.Numeral.Helpers (numberWith)
import Duckling.Numeral.Types (NumeralData(..), isInteger)
import Duckling.Duration.Types (DurationData (DurationData))
import Duckling.Regex.Types
import Duckling.Types
import Duckling.TimeGrain.Types
import qualified Duckling.Duration.Types as TDuration
import qualified Duckling.Numeral.Types as TNumeral
import qualified Duckling.TimeGrain.Types as TG

ruleHalves :: Rule
ruleHalves = Rule
  { name = "half of a <time-grain>"
  , pattern =
    [ regex "половин"
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_) -> Token Duration <$> timesOneAndAHalf grain 0
      _ -> Nothing
  }

ruleGrainAndAHalf :: Rule
ruleGrainAndAHalf = Rule
  { name = "<time-grain> and a half"
  , pattern =
    [ dimension TimeGrain
    , regex "и половина"
    ]
  , prod = \tokens -> case tokens of
      (Token TimeGrain grain:_) -> Token Duration <$> timesOneAndAHalf grain 1
      _ -> Nothing
  }

ruleDurationAndAHalf :: Rule
ruleDurationAndAHalf = Rule
  { name = "<positive-numeral> <time-grain> and a half"
  , pattern =
    [ Predicate isNatural
    , dimension TimeGrain
    , regex "и половина"
    ]
  , prod = \tokens -> case tokens of
      (Token Numeral NumeralData{TNumeral.value = v}:
       Token TimeGrain grain:
       _) -> timesOneAndAHalf grain (floor $ v) >>= Just . Token Duration
      _ -> Nothing
  }

ruleNumeralQuotes :: Rule
ruleNumeralQuotes = Rule
  { name = "<integer> + '\""
  , pattern =
    [ Predicate isNatural
    , regex "(['\"])"
    ]
  , prod = \tokens -> case tokens of
      (Token Numeral NumeralData{TNumeral.value = v}:
       Token RegexMatch (GroupMatch (x:_)):
       _) -> case x of
         "'"  -> Just . Token Duration . duration Minute $ floor v
         "\"" -> Just . Token Duration . duration Second $ floor v
         _    -> Nothing
      _ -> Nothing
  }

ruleDurationPrecision :: Rule
ruleDurationPrecision = Rule
  { name = "about|exactly <duration>"
  , pattern =
    [ regex "(към|приблизително|примерно|някъде)"
    , dimension Duration
    ]
    , prod = \tokens -> case tokens of
        (_:token:_) -> Just token
        _ -> Nothing
  }

ruleGrainAsDuration :: Rule
ruleGrainAsDuration = Rule
  { name = "a <unit-of-duration>"
  , pattern =
    [ regex "(секунда|минута|час|ден|седмица|месец|тримесечие|година)"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (x:_)):_) -> case x of
        "секунда"    -> Just . Token Duration $ duration TG.Second 1
        "минута"     -> Just . Token Duration $ duration TG.Minute 1
        "час"        -> Just . Token Duration $ duration TG.Hour 1
        "ден"        -> Just . Token Duration $ duration TG.Day 1
        "седмица"    -> Just . Token Duration $ duration TG.Week 1
        "месец"      -> Just . Token Duration $ duration TG.Month 1
        "тримесечие" -> Just . Token Duration $ duration TG.Quarter 1
        "година"     -> Just . Token Duration $ duration TG.Year 1
        _    -> Nothing
      _ -> Nothing
  }

rulePositiveDuration :: Rule
rulePositiveDuration = Rule
  { name = "<positive-numeral> <time-grain>"
  , pattern =
    [ numberWith TNumeral.value $ and . sequence [not . isInteger, (>0)]
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (Token Numeral NumeralData{TNumeral.value = v}:
       Token TimeGrain grain:
       _) -> Just . Token Duration . duration Second . floor $ inSeconds grain v
      _ -> Nothing
  }

ruleCompositeDuration :: Rule
ruleCompositeDuration = Rule
  { name = "composite <duration> (with ,/and)"
  , pattern =
    [ Predicate isNatural
    , dimension TimeGrain
    , regex ",|и"
    , dimension Duration
    ]
  , prod = \case
      (Token Numeral NumeralData{TNumeral.value = v}:
       Token TimeGrain g:
       _:
       Token Duration dd@DurationData{TDuration.grain = dg}:
       _) | g > dg -> Just . Token Duration $ duration g (floor v) <> dd
      _ -> Nothing
  }

rules :: [Rule]
rules =
  [ ruleDurationAndAHalf
  , ruleCompositeDuration
  , ruleGrainAndAHalf
  , rulePositiveDuration
  , ruleDurationPrecision
  , ruleNumeralQuotes
  , ruleGrainAsDuration
  , ruleHalves
  ]
