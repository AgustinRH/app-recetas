import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToOne,
  OneToMany,
} from 'typeorm';
import { UserPreferences } from './user-preferences.entity';
import { PantryItem } from './pantry-item.entity';
import { Recipe } from './recipe.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  firebaseUid: string;

  @Column({ type: 'varchar', nullable: true })
  email: string | null;

  @Column()
  displayName: string;

  @Column({ type: 'varchar', nullable: true })
  avatarUrl: string | null;

  @Column({ default: false })
  isAdmin: boolean;

  @Column({ default: false })
  banned: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @OneToOne(() => UserPreferences, (p) => p.user, { cascade: true })
  preferences: UserPreferences;

  @OneToMany(() => PantryItem, (p) => p.user)
  pantry: PantryItem[];

  @OneToMany(() => Recipe, (r) => r.author)
  recipes: Recipe[];
}
