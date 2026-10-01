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

/** Una comida o una cena de una semana concreta. */
@Entity('meal_slots')
@Unique(['userId', 'weekStart', 'dayIndex', 'meal'])
export class MealSlot {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  /** Lunes de esa semana, YYYY-MM-DD. */
  @Column({ type: 'date' })
  weekStart: string;

  /** 0 = lunes … 6 = domingo. */
  @Column({ type: 'smallint' })
  dayIndex: number;

  /** 'comida' | 'cena' */
  @Column()
  meal: string;

  @Column()
  recipeId: string;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Recipe, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipeId' })
  recipe: Recipe;
}
