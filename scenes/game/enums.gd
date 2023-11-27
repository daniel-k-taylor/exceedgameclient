extends Node

enum PlayerId {
	PlayerId_Player,
	PlayerId_Opponent,
}

enum CardZone {
	CardZone_PlayerHand,
	CardZone_PlayerGauge,
	CardZone_PlayerBoosts,
	CardZone_OpponentHand,
	CardZone_OpponentGauge,
	CardZone_OpponentBoosts,
}

enum DecisionType {
	DecisionType_BoostCancel,
	DecisionType_BoostNow,
	DecisionType_ChooseArenaLocationForEffect,
	DecisionType_ChooseDiscardContinuousBoost,
	DecisionType_ChooseDiscardOpponentGauge,
	DecisionType_ChooseFromBoosts,			# 5
	DecisionType_ChooseFromDiscard,
	DecisionType_ChooseFromTopDeck,
	DecisionType_ChooseSimultaneousEffect,
	DecisionType_EffectChoice,
	DecisionType_ForceBoostSustainTopdeck,
	DecisionType_ForceForEffect,
	DecisionType_GaugeForEffect,
	DecisionType_NameCard_OpponentDiscards, # 13
	DecisionType_ChooseToDiscard,
	DecisionType_PayStrikeCost_Required,
	DecisionType_PayStrikeCost_CanWild,
	DecisionType_ForceForArmor,
	DecisionType_CardFromHandToGauge,
	DecisionType_ReadingNormal,
	DecisionType_StrikeNow,
}

enum GameState {
	GameState_AutoStrike,
	GameState_NotStarted,
	GameState_Boost_Processing,
	GameState_GameOver,
	GameState_PickAction,
	GameState_DiscardDownToMax,
	GameState_Mulligan,				#5
	GameState_WaitForStrike,
	GameState_PlayerDecision,
	GameState_Strike_Opponent_Response,
	GameState_Strike_Processing,
}

enum GameOverReason {
	GameOverReason_Life,
	GameOverReason_Decked,
	GameOverReason_Disconnect,
	GameOverReason_Quit,
}

enum EventType {
	EventType_AddToGauge,
	EventType_AddToDiscard,
	EventType_AddToDeck,
	EventType_AddToHand,
	EventType_AdvanceTurn,
	EventType_Boost_ActionAfterBoost,
	EventType_Boost_CancelDecision, 			# 6
	EventType_Boost_DiscardContinuousChoice,
	EventType_Boost_DiscardOpponentGauge,
	EventType_Boost_Played,
	EventType_Boost_Canceled,
	EventType_Boost_Continuous_Added,
	EventType_Boost_NameCardOpponentDiscards, 	# 12
	EventType_CardFromHandToGauge_Choice,
	EventType_ChangeCards,
	EventType_CharacterAction,
	EventType_ChooseArenaLocationForEffect,
	EventType_ChooseFromBoosts,
	EventType_ChooseFromDiscard,
	EventType_ChooseFromTopDeck,
	EventType_Draw,
	EventType_Exceed, 							# 21
	EventType_ExceedRevert,
	EventType_ForceForEffect,
	EventType_GaugeForEffect,
	EventType_ForceStartBoost,
	EventType_ForceStartStrike,
	EventType_GameOver,
	EventType_HandSizeExceeded,
	EventType_Move,
	EventType_MulliganDecision, 				# 30
	EventType_PlaceBuddy,
	EventType_Prepare,
	EventType_ReadingNormal,
	EventType_ReshuffleDeck_Mulligan,
	EventType_ReshuffleDiscard,
	EventType_RevealHand,
	EventType_RevealStrike_OnePlayer,
	EventType_RevealTopDeck,
	EventType_Seal,
	EventType_SetCardAside,
	EventType_Strike_ArmorUp,
	EventType_Strike_CardActivation,
	EventType_Strike_CharacterEffect,
	EventType_Strike_DodgeAttacks,
	EventType_Strike_DodgeAttacksAtRange,
	EventType_Strike_DoResponseNow,             # 46
	EventType_Strike_EffectChoice,
	EventType_Strike_ExUp,
	EventType_Strike_ForceForArmor,
	EventType_Strike_ForceWildSwing,
	EventType_Strike_GainAdvantage,
	EventType_Strike_GuardUp,
	EventType_Strike_IgnoredPushPull,
	EventType_Strike_Miss,
	EventType_Strike_ChooseToDiscard,
	EventType_Strike_ChooseToDiscard_Info,
	EventType_Strike_OpponentCantMovePast,
	EventType_Strike_PayCost_Gauge,
	EventType_Strike_PayCost_Force,
	EventType_Strike_PayCost_Unable,
	EventType_Strike_PowerUp,					# 61
	EventType_Strike_RangeUp,
	EventType_Strike_Response,
	EventType_Strike_Response_Ex,
	EventType_Strike_Reveal,
	EventType_Strike_SpeedUp,
	EventType_Strike_Started,
	EventType_Strike_Started_Ex,
	EventType_Strike_Stun,
	EventType_Strike_Stun_Immunity,
	EventType_Strike_TookDamage,
	EventType_Strike_WildStrike,
	EventType_SustainBoost,
}
