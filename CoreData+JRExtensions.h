/*******************************************************************************
	CoreData+JRExtensions.h
		Copyright (c) 2006-2011 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Cocoa/Cocoa.h>

@interface NSManagedObject (JRExtensions)
+ (id)jr_insertInMoc:(NSManagedObjectContext*)moc_;

+ (id)jr_rootObjectInMoc:(NSManagedObjectContext*)moc_;
+ (id)jr_rootObjectInMoc:(NSManagedObjectContext*)moc_ error:(NSError**)error_;

+ (NSArray*)jr_fetchAll:(NSManagedObjectContext*)moc_;
+ (NSArray*)jr_fetchAll:(NSManagedObjectContext*)moc_ error:(NSError**)error_;

+ (NSString*)jr_entityNameByHeuristic; // MyCoolObjectMO => @"MyCoolObject".
+ (NSEntityDescription*)jr_entityDescriptionInMoc:(NSManagedObjectContext*)moc_;
+ (NSFetchRequest*)jr_fetchRequestForEntityInMoc:(NSManagedObjectContext*)moc_;

+ (NSString*)jr_defaultSortKeyWithMoc:(NSManagedObjectContext*)moc_;

- (NSString*)jr_objectURLID;

#if NS_BLOCKS_AVAILABLE
typedef void (^JRManagedObjectBlock)(NSManagedObject *mo);
- (void)jr_uponWillDelete:(JRManagedObjectBlock)block_;
#endif
@end

@interface NSManagedObjectContext (JRExtensions)
- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_;
- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ error:(NSError**)error_;
- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_;
- (NSArray*)jr_executeFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_ error:(NSError**)error_;
- (id)jr_executeSingleResultFetchRequestNamed:(NSString*)fetchRequestName_ substitutionVariables:(NSDictionary*)variables_ error:(NSError**)error_;

- (id)jr_objectWithURLID:(NSString*)url_;
@end

@interface NSNotification (JRExtensions)
- (NSSet*)jr_insertedObjects;
- (NSSet*)jr_updatedObjects;
- (NSSet*)jr_deletedObjects;

- (NSSet*)jr_deletedObjectsOfClass:(Class)cls_;
@end