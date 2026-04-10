export const PracticeRequestType = {
  upsertPlayer: 1000,
  playerProfile: 1001,
  leaderboard: 1002,
} as const;

export const PracticeUpdateType = {
  matchResult: "practice_match_result",
  queueRating: "practice_queue_rating",
  presence: "practice_presence",
} as const;
