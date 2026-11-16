import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  Unique,
  CreateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Recipe } from './recipe.entity';

export const REPORT_REASONS = [
  'inapropiado',
  'spam',
  'incorrecta',
  'derechos',
  'otro',
] as const;

export const REPORT_REASON_LABELS: Record<
  (typeof REPORT_REASONS)[number],
  string
> = {
  inapropiado: 'Contenido inapropiado',
  spam: 'Spam o publicidad',
  incorrecta: 'Receta incorrecta o peligrosa',
  derechos: 'Derechos de la foto o el texto',
  otro: 'Otro',
};

/** Una denuncia de un usuario sobre una receta. Una por persona y receta. */
@Entity('recipe_reports')
@Unique(['userId', 'recipeId'])
export class RecipeReport {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  recipeId: string;

  @Column()
  reason: string;

  @Column({ type: 'text', default: '' })
  note: string;

  /** 'open' | 'dismissed' */
  @Column({ default: 'open' })
  status: string;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Recipe, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipeId' })
  recipe: Recipe;
}
