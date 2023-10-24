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
	DecisionType_ChooseDiscardContinuousBoost,
	DecisionType_ChooseFromDiscard,
	DecisionType_EffectChoice,
	DecisionType_ForceForEffect,
	DecisionType_NameCard_OpponentDiscards, # 5
	DecisionType_ChooseToDiscard,
	DecisionType_PayStrikeCost_Required,
	DecisionType_PayStrikeCost_CanWild,
	DecisionType_ForceForArmor,
	DecisionType_CardFromHandToGauge,
	DecisionType_ReadingNormal,
	DecisionType_StrikeNow,
}

enum GameState {
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
	EventType_Boost_Played,
	EventType_Boost_Canceled,
	EventType_Boost_Continuous_Added,
	EventType_Boost_NameCardOpponentDiscards, 	# 11
	EventType_CardFromHandToGauge_Choice,
	EventType_ChangeCards,
	EventType_ChooseFromDiscard,
	EventType_Discard,
	EventType_Draw,
	EventType_Exceed, 							# 17
	EventType_ForceForEffect,
	EventType_ForceStartStrike,
	EventType_GameOver,
	EventType_HandSizeExceeded,
	EventType_Move,
	EventType_MulliganDecision, 				# 23
	EventType_Prepare,
	EventType_ReadingNormal,
	EventType_ReshuffleDeck_Mulligan,
	EventType_ReshuffleDiscard,
	EventType_RevealHand,
	EventType_RevealTopDeck,
	EventType_Strike_ArmorUp,
	EventType_Strike_CardActivation,
	EventType_Strike_CharacterEffect,
	EventType_Strike_DodgeAttacks,
	EventType_Strike_EffectChoice,
	EventType_Strike_ExUp,
	EventType_Strike_ForceForArmor, # 36
	EventType_Strike_ForceWildSwing,
	EventType_Strike_GainAdvantage,
	EventType_Strike_GuardUp,
	EventType_Strike_IgnoredPushPull,
	EventType_Strike_Miss,
	EventType_Strike_ChooseToDiscard,
	EventType_Strike_ChooseToDiscard_Info,
	EventType_Strike_PayCost_Gauge,
	EventType_Strike_PayCost_Force,
	EventType_Strike_PayCost_Unable,
	EventType_Strike_PowerUp,
	EventType_Strike_RangeUp,
	EventType_Strike_Response,
	EventType_Strike_Response_Ex,
	EventType_Strike_Reveal,
	EventType_Strike_SpeedUp,
	EventType_Strike_Started, # 53
	EventType_Strike_Started_Ex,
	EventType_Strike_Stun,
	EventType_Strike_Stun_Immunity,
	EventType_Strike_TookDamage,
	EventType_Strike_WildStrike,
}
