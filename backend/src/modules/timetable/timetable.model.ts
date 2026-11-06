import { model, Schema } from 'mongoose';

export const SESSION_KINDS = ['lecture', 'lab', 'exam', 'workshop'] as const;
export type SessionKind = (typeof SESSION_KINDS)[number];

/** A class of the weekly template. Times are wall-clock 'HH:mm' on campus. */
export interface TimetableSlot {
  /** Prefix of the session ids ('algo' -> 'algo-2026-11-5'). */
  slotId: string;
  /** 1 = Monday ... 7 = Sunday. */
  weekday: number;
  course: string;
  room: string;
  teacher: string;
  start: string;
  end: string;
  kind: SessionKind;
  lectureNumber: number | null;
  lectureCount: number | null;
  coefficient: number | null;
  notes: string | null;
}

/** The weekly timetable of a class group: the same classes every week. */
export interface TimetableTemplate {
  classGroup: string;
  slots: TimetableSlot[];
}

const slotSchema = new Schema<TimetableSlot>(
  {
    slotId: { type: String, required: true },
    weekday: { type: Number, required: true, min: 1, max: 7 },
    course: { type: String, required: true },
    room: { type: String, required: true },
    teacher: { type: String, required: true },
    start: { type: String, required: true, match: /^\d{2}:\d{2}$/ },
    end: { type: String, required: true, match: /^\d{2}:\d{2}$/ },
    kind: { type: String, enum: SESSION_KINDS, default: 'lecture' },
    lectureNumber: { type: Number, default: null },
    lectureCount: { type: Number, default: null },
    coefficient: { type: Number, default: null },
    notes: { type: String, default: null },
  },
  { _id: false },
);

const templateSchema = new Schema<TimetableTemplate>(
  {
    classGroup: { type: String, required: true, unique: true },
    slots: { type: [slotSchema], default: [] },
  },
  { timestamps: true },
);

export const TimetableTemplateModel = model<TimetableTemplate>(
  'TimetableTemplate',
  templateSchema,
);
