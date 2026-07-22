// PAWD shared types — mirror the Supabase schema (0001–0004).

export type Species = 'dog' | 'cat';
export type PetSex = 'male' | 'female';
export type PurposeFlag = 'playdates' | 'walking' | 'friends' | 'breeding';
export type VaccStatus = 'unknown' | 'partial' | 'up_to_date';
export type SwipeDir = 'like' | 'pass';
export type ReportReason =
  | 'fake_profile'
  | 'welfare_concern'
  | 'harassment'
  | 'scam'
  | 'spam';

export interface Owner {
  id: string;
  display_name: string;
  photo_url: string | null;
  city: string | null;
  area: string | null;
  phone_verified: boolean;
  age_attested: boolean;
  is_banned: boolean;
}

export interface Pet {
  id: string;
  owner_id: string;
  name: string;
  species: Species;
  breed: string;
  sex: PetSex;
  date_of_birth: string | null;
  weight_kg: number | null;
  neutered: boolean | null;
  vaccination: VaccStatus;
  temperament: string[];
  energy_level: number;
  bio: string | null;
  purposes: PurposeFlag[];
  is_active: boolean;
}

export interface DeckCard {
  pet_id: string;
  name: string;
  species: Species;
  breed: string;
  sex: PetSex;
  age_months: number | null;
  energy_level: number;
  temperament: string[];
  bio: string | null;
  purposes: PurposeFlag[];
  vaccination: VaccStatus;
  owner_display_name: string;
  distance_km: number;
  primary_photo: string | null;
}

export interface MatchRow {
  match_id: string;
  matched_at: string;
  my_pet: string;
  other_pet: string;
  other_pet_name: string;
  other_owner: string;
  other_owner_name: string;
  other_primary_photo: string | null;
  last_message: string | null;
  last_message_at: string | null;
}

export interface Message {
  id: string;
  match_id: string;
  sender_id: string;
  body: string | null;
  image_path: string | null;
  created_at: string;
}

export const PURPOSE_LABELS: Record<PurposeFlag, string> = {
  playdates: 'Playdates',
  walking: 'Walking buddy',
  friends: 'Pet friends',
  breeding: 'Breeding',
};

export const VACC_LABELS: Record<VaccStatus, string> = {
  unknown: 'Unknown',
  partial: 'Partial',
  up_to_date: 'Up to date',
};

export const STORAGE_PUBLIC_URL = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public`;

export function photoUrl(bucket: string, path: string | null): string | null {
  if (!path) return null;
  return `${STORAGE_PUBLIC_URL}/${bucket}/${path}`;
}
